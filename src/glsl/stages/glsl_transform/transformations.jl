# utility for zero-based indexing transformation
function wrap_minus_one(node::GLSLASTNode)
    if node isa GLSLLiteral
        @debug_assert node.type in [GLSLInt, GLSLUInt]

        node.value -= 1

        return node
    end

    # fall back to manually subtracting one
    GLSLCall(GLSLSymbol(:(-)), [node, GLSLLiteral(1)])
end

function transform_children!(
    state::GLSLTransformState, ctx::GTContext, first::Int=1, last::Int=length(state.typed_node.children);
    init_children::Bool=true#, skip_predicates::Vector{<:Function}=Vector()
)
    if init_children
        state.children = Vector{GLSLTransformState}(undef, length(state.typed_node.children))
    end

    for (i, child) in enumerate(state.typed_node.children[first:last])
        idx = first + i - 1

        child_state = GLSLTransformState(child)

        glsl_transform!(child_state, ctx)

        state.children[idx] = child_state
    end
end

glsl_transform!(state::GLSLTransformState, ctx::GTContext) =
    glsl_transform!(state, tag_match(ASTConstructTag, state.typed_node), ctx)

function glsl_transform!(state::GLSLTransformState, ::Type{DefaultTag}, ctx::GTContext)
    if state.original[] isa Expr && state.original[].head == :(.)
        return
    end

    error("Cannot continue transpilation, found untagged node during GLSL IR transformation: ", tree_node_string(state.typed_node))
end

function glsl_transform!(state::GLSLTransformState, ::Type{LiteralTag}, ctx::GTContext)
    state.glsl_node = GLSLLiteral(state.typed_node.original[])
end

function glsl_transform!(state::GLSLTransformState, ::Type{SymbolTag}, ctx::GTContext)
    state.glsl_node = GLSLSymbol(state.typed_node.original[])
end

function glsl_transform!(state::GLSLTransformState, ::Type{BlockTag}, ctx::GTContext)
    transform_children!(state, ctx)

    state.glsl_node = GLSLBlock(glsl_children(state))
end

function glsl_transform!(state::GLSLTransformState, ::Type{AssignmentTag}, ctx::GTContext)
    transform_children!(state, ctx)

    @debug_assert length(state.children) == 2

    lhs = state.children[1].glsl_node
    @debug_assert typeof(lhs) in [GLSLSymbol, GLSLSwizzle, GLSLArrayIndexer]

    target_sym = lhs isa GLSLSymbol ? lhs.sym : (lhs isa GLSLSwizzle && lhs.base isa GLSLSymbol) ? lhs.base.sym : nothing

    if !isnothing(target_sym)
        inter_decl_idx = findfirst(decl -> decl.symbol.sym == target_sym, ctx.pipeline_ctx.interface_decls)
        is_const = !isnothing(inter_decl_idx) &&
            any(q -> q isa ConstantQualifier, ctx.pipeline_ctx.interface_decls[inter_decl_idx].qualifiers)

        param_decl_idx = findfirst(decl -> decl.symbol.sym == target_sym, ctx.param_decls)
        is_immutable = !isnothing(param_decl_idx) &&
            any(q -> typeof(q) in [InQualifier,UniformQualifier], ctx.param_decls[param_decl_idx].qualifiers)

        if is_const || is_immutable
            ast_error(state.original, "Trying to reassign a const or immutable variable: ", target_sym)
        end
    end

    state.glsl_node = GLSLAssignment(lhs, state.children[2].glsl_node)
end

function glsl_transform!(state::GLSLTransformState, ::Type{CallTag}, ctx::GTContext)
    name_expr = state.original[].args[1]
    is_outside_fn = false

    if name_expr isa Expr && name_expr.head == :(.)
        f = resolve_module_chain(name_expr, ctx.defining_module)

        if parentmodule(f) != JuliaGLM
            ast_error(name_expr, "Invalid outside function access: trying to call function $f, which is not a part of the JuliaGLM module")
        end

        is_outside_fn = true
    end

    transform_children!(state, ctx)

    if is_outside_fn
        fstate = GLSLTransformState(state.typed_node.children[1])
        fstate.glsl_node = GLSLSymbol(nameof(f))

        state.children[1] = fstate
    end

    @debug_assert !isempty(state.children)
    @debug_assert state.children[1].glsl_node isa GLSLSymbol

    is_broadcasted = state.children[1].glsl_node.sym == :broadcast
    first_arg_idx = is_broadcasted ? 3 : 2
    @debug_assert all(child -> child.typed_node.type <: ASTValueType, state.children[first_arg_idx:end])

    fsym_idx = is_broadcasted ? 2 : 1
    fsym = state.children[fsym_idx].glsl_node.sym

    # ctor calls
    type = isdefined(ctx.defining_module, fsym) && ctx.defining_module.eval(:(typeof($fsym)))
    if type == DataType
        glsl_type = to_glsl_type(getfield(ctx.defining_module, fsym))
        state.children[fsym_idx].glsl_node = GLSLTypeSymbol(glsl_type)
    end

    state.glsl_node = GLSLCall(state.children[fsym_idx].glsl_node, glsl_children(state, first=first_arg_idx))
end

function glsl_transform!(state::GLSLTransformState, ::Type{ReturnTag}, ctx::GTContext)
    if state.typed_node.type == ASTVoid
        state.glsl_node = GLSLReturn(nothing)
        return
    end

    transform_children!(state, ctx)

    @debug_assert length(state.children) == 1

    ret_node = state.children[1]
    ret_type = ret_node.typed_node.type

    @debug_assert ret_type <: ASTValueType

    state.glsl_node = GLSLReturn(ret_node.glsl_node)
end

function glsl_transform!(state::GLSLTransformState, ::Type{BreakTag}, ctx::GTContext)
    transform_children!(state, ctx)

    state.glsl_node = GLSLBreak()
end

function glsl_transform!(state::GLSLTransformState, ::Type{ContinueTag}, ctx::GTContext)
    transform_children!(state, ctx)

    state.glsl_node = GLSLContinue()
end

function glsl_transform!(state::GLSLTransformState, ::Type{DeclTag}, ctx::GTContext)
    state.glsl_node = GLSLEmptyNode()
end

# if-s are kinda tricky, because they are stored in a nested, recursive way
# we unroll them here
#   1) to check their structure during the transformation stage
#   2) for easier code gen
function glsl_transform_if!(state::GLSLTransformState, ctx::GTContext)
    tnode = state.typed_node
    expr = tnode.original[]

    @debug_assert expr.head == :if || expr.head == :elseif
    @debug_assert 2 <= length(expr.args) <= 3

    if tnode.children[1].type != ASTBool
        ast_error(expr, "If or elseif condition doesn't resolve to a bool value")
    end

    @debug_assert expr.args[2] isa Expr && expr.args[2].head == :block
    @debug_assert length(expr.args) != 3 || (expr.args[3] isa Expr && expr.args[3].head in [:block, :elseif])

    condition = GLSLTransformState(tnode.children[1])
    glsl_transform!(condition, ctx)

    body = GLSLTransformState(tnode.children[2])
    glsl_transform!(body, ctx)
    @debug_assert body.glsl_node isa GLSLBlock

    if length(expr.args) < 3
        state.glsl_node = GLSLIf(condition.glsl_node, body.glsl_node)
        return
    end

    last_branch = GLSLTransformState(tnode.children[3])

    if expr.args[3].head == :elseif
        # last_branch is an else if branch
        glsl_transform_if!(last_branch, ctx)
        state.glsl_node = GLSLIf(condition.glsl_node, body.glsl_node, [last_branch.glsl_node], nothing)
    else
        # last_branch is an else branch
        glsl_transform!(last_branch, ctx)
        @debug_assert last_branch.glsl_node isa GLSLBlock
        state.glsl_node = GLSLIf(condition.glsl_node, body.glsl_node, Vector(), last_branch.glsl_node)
    end
end

has_nested_elseif(if_node::GLSLIf) = !isempty(if_node.elseif_branches) && !isempty(if_node.elseif_branches[end].elseif_branches)

function flatten_if!(if_node::GLSLIf)
    while has_nested_elseif(if_node)
        nested_elseif = if_node.elseif_branches[end]

        @debug_assert length(nested_elseif.elseif_branches) == 1
        nested_branch = nested_elseif.elseif_branches[1]

        push!(if_node.elseif_branches, nested_branch)
        nested_elseif.elseif_branches = Vector()
    end

    for elseif_branch in if_node.elseif_branches
        if elseif_branch.condition isa GLSLBlock
            @debug_assert length(elseif_branch.condition.body) == 1
            elseif_branch.condition = elseif_branch.condition.body[1]
        end
    end

    if length(if_node.elseif_branches) == 0
        return
    end

    last_elseif = if_node.elseif_branches[end]
    if !isnothing(last_elseif.else_branch)
        if_node.else_branch = last_elseif.else_branch
        last_elseif.else_branch = nothing
    end
end

function assert_flattened_if(if_node::GLSLIf, in_elseif=false)
    if in_elseif
        @debug_assert isempty(if_node.elseif_branches)
        @debug_assert isnothing(if_node.else_branch)
        @debug_assert !(if_node.condition isa GLSLBlock)
    else
        for elseif_branch in if_node.elseif_branches
            assert_flattened_if(elseif_branch)
        end
    end
end

function glsl_transform!(state::GLSLTransformState, ::Type{IfTag}, ctx::GTContext)
    glsl_transform_if!(state, ctx)
    flatten_if!(state.glsl_node)
    assert_flattened_if(state.glsl_node)
end

function glsl_transform!(state::GLSLTransformState, ::Type{WhileTag}, ctx::GTContext)
    transform_children!(state, ctx)

    @debug_assert length(state.children) == 2
    @debug_assert state.children[1].typed_node.type == ASTBool
    @debug_assert state.children[2].glsl_node isa GLSLBlock

    state.glsl_node = GLSLWhile(state.children[1].glsl_node, state.children[2].glsl_node)
end

function glsl_transform!(state::GLSLTransformState, ::Type{ForTag}, ctx::GTContext)
    tnode = state.typed_node

    @debug_assert length(tnode.children) == 2

    it = tnode.children[1]
    body = tnode.children[2]

    body_state = GLSLTransformState(body)
    glsl_transform!(body_state, ctx)


end

function glsl_transform!(state::GLSLTransformState, ::Type{SwizzleTag}, ctx::GTContext)
    transform_children!(state, ctx, 1, 1)

    # TODO: move swizzle validation here

    swizzle = state.typed_node.children[2].original[]
    @debug_assert swizzle isa String

    state.glsl_node = GLSLSwizzle(state.children[1].glsl_node, swizzle)
end

function glsl_transform!(state::GLSLTransformState, ::Type{IndexerTag}, ctx::GTContext)
    transform_children!(state, ctx)

    target = state.children[1]
    target_type = target.typed_node.type

    if target_type <: ASTMat
        # mat indexing
        (n, m) = size(to_ast(target_type))

        indices = state.children[2:end]

        result = nothing

        if length(indices) == 1
            idx = indices[1]

            if !is_ast_integer(idx.typed_node.type)
                ast_error(state.original[], "Invalid single-argument indexer type for matrix type $(target_type): $(idx.typed_node.type)")
            end

            # check that literals can't be out of bounds
            if idx.original[] isa ASTLiteral && (idx.original[] < 1 || idx.original[] > n * m)
                ast_error(state.original[], "Element indexer literal's value is considered out of bounds for matrix type $(target_type)")
            end

            # col idx: ⌊(idx - 1) / n⌋
            # row idx: (idx - 1) % n
            col_idx = GLSLCall(GLSLSymbol(:/), [wrap_minus_one(idx.glsl_node), GLSLLiteral(n)])
            row_idx = GLSLCall(GLSLSymbol(:%), [wrap_minus_one(idx.glsl_node), GLSLLiteral(n)])

            result = GLSLMatIndexer(target.glsl_node, col_idx, row_idx)
        elseif length(indices) == 2
            row_idx = indices[1]
            col_idx = indices[2]

            if col_idx.original[] == row_idx.original[] == :(:)
                result = target.glsl_node
            elseif row_idx.original[] == :(:) && is_ast_integer(col_idx.typed_node.type)
                if col_idx.original[] isa ASTLiteral && (col_idx.original[] < 1 || col_idx.original[] > m)
                    ast_error(state.original[], "Column indexer literal's value is considered out of bounds matrix type $(target_type)")
                end

                result = GLSLMatIndexer(target.glsl_node, wrap_minus_one(col_idx.glsl_node), nothing)
            elseif col_idx.original[] == :(:) && is_ast_integer(row_idx.typed_node.type)
                ast_error(state.original[], "Cannot natively access row of a matrix as VecN because of OpenGL's column-major matrix representation")
            elseif is_ast_integer(col_idx.typed_node.type) && is_ast_integer(row_idx.typed_node.type)
                result = GLSLMatIndexer(target.glsl_node, wrap_minus_one(col_idx.glsl_node), wrap_minus_one(row_idx.glsl_node))
            end
        end

        if isnothing(result)
            ast_error(state.original[], "Invalid or unsupported indexer for matrix type $(target.type)")
        end

        state.glsl_node = result
    elseif target_type <: ASTVec
        idx = state.original[].args[2]
        @debug_assert 1 <= idx <= length(state.children[1].typed_node.type)

        state.glsl_node = GLSLSwizzle(state.children[1].glsl_node, "xyzw"[idx] |> string)
    elseif target_type <: ASTList
        idx_node = wrap_minus_one(state.children[2].glsl_node)

        @debug_assert length(state.children) == 2
        @debug_assert state.children[2].typed_node.type <: Union{ASTInt32,ASTInt64,ASTUInt32}

        state.glsl_node = GLSLArrayIndexer(state.children[1].glsl_node, idx_node)
    else
        ast_error(state.original[], "Indexing into invalid type: $(target_type)")
    end
end

function glsl_transform!(state::GLSLTransformState, ::Type{LogicalOperatorTag}, ctx::GTContext)
    transform_children!(state, ctx)

    if state.original[].head == :(&&)
        @debug_assert length(state.children) == 2
        @debug_assert state.children[1].typed_node.type == ASTBool
        @debug_assert state.children[2].typed_node.type == ASTBool

        state.glsl_node = GLSLLogicalAnd(glsl_children(state)...)
    elseif state.original[].head == :(||)
        @debug_assert length(state.children) == 2
        @debug_assert state.children[1].typed_node.type == ASTBool
        @debug_assert state.children[2].typed_node.type == ASTBool

        state.glsl_node = GLSLLogicalOr(glsl_children(state)...)
    elseif state.original[].head == :call
        if state.children[1].original[] == :(!)
            @debug_assert length(state.children) == 2

            arg_type = state.children[2].typed_node.type
            if arg_type != ASTBool
                ast_error(state.original[], "Boolean negation's argument was $arg_type instead of a boolean value")
            end

            state.glsl_node = GLSLLogicalNeg(state.children[2].glsl_node)
        elseif state.children[1].original[] == :(⊻)
            @debug_assert length(state.children) == 3

            lhs_type = state.children[2].typed_node.type
            rhs_type = state.children[3].typed_node.type
            if lhs_type != ASTBool || rhs_type != ASTBool
                ast_error(state.original[], "Boolean XOR's argument types were ($lhs_type, $rhs_type) instead of (ASTBool, ASTBool)")
            end

            state.glsl_node = GLSLLogicalXor(glsl_children(state, first=2)...)
        end
    end
end

function glsl_transform!(state::GLSLTransformState, ::Type{ArrayLiteralTag}, ctx::GTContext)
    transform_children!(state, ctx)
    
    t = eltype(state.typed_node.type) |> to_glsl_type
    arr_lit = state.children

    @debug_assert all(el -> el.glsl_node isa GLSLLiteral, arr_lit)

    if !all(el -> el.glsl_node.type == t, arr_lit)
        ast_error(state.original[],
            "Found array literal where the core-inferred element type's GLSL type projection doesn't match one of the element's GLSL type:\n",
            join(state.original[].args, ",")
        )
    end

    state.glsl_node = GLSLArrayLiteral([glsl_children(state)...])
end

precomp_subtypes(ASTConstructTag, glsl_transform!, (GLSLTransformState, missing, GTContext))
