function transform_children!(state::GLSLTransformState, ctx::GTContext, first::Int=1, last::Int=-1)
    tnode = state.typed_node

    n = length(tnode.children)
    if last == -1
        last = n
    end

    state.children = Vector{GLSLTransformState}(undef, last - first + 1)

    # n = last - first + 1
    # f(1) = first
    # f(n) = last
    for (i, child) in enumerate(tnode.children[first:last])
        idx = first + i - 1

        child_state = GLSLTransformState(child)
        glsl_transform!(child_state, ctx)

        state.children[idx] = child_state
    end
end

glsl_transform!(state::GLSLTransformState, ctx::GTContext) =
    glsl_transform!(state, tag_match(ASTConstructTag, state.typed_node), ctx)

function glsl_transform!(state::GLSLTransformState, ::Type{DefaultTag}, ctx::GTContext)
    println("Found untagged node:")
    println(tree_node_string(state.typed_node))
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

    @assert length(state.children) == 2
    @assert state.children[1].glsl_node isa GLSLSymbol

    state.glsl_node = GLSLAssignment(state.children[1].glsl_node, state.children[2].glsl_node)
end

function glsl_transform!(state::GLSLTransformState, ::Type{CallTag}, ctx::GTContext)
    transform_children!(state, ctx)

    @assert !isempty(state.children)
    @assert state.children[1].glsl_node isa GLSLSymbol

    is_broadcasted = state.children[1].glsl_node.sym == :broadcast
    first_arg_idx = is_broadcasted ? 3 : 2
    @assert all(child -> child.typed_node.type <: ASTValueType, state.children[first_arg_idx:end])

    fsym_idx = is_broadcasted ? 2 : 1
    fsym = state.children[fsym_idx].glsl_node.sym
    @assert isdefined(ctx.defining_module, fsym)

    # ctor calls
    type = ctx.defining_module.eval(:(typeof($fsym)))
    if type == DataType
        glsl_type = to_glsl_type(TypeInference.to_tast(getfield(ctx.defining_module, fsym)))
        state.children[fsym_idx].glsl_node = GLSLTypeSymbol(glsl_type)
    end

    state.glsl_node = GLSLCall(state.children[fsym_idx].glsl_node, glsl_children(state, first=first_arg_idx))
end

function glsl_transform!(state::GLSLTransformState, ::Type{ReturnTag}, ctx::GTContext)
    transform_children!(state, ctx)

    @assert length(state.children) == 1

    ret_node = state.children[1]
    ret_type = ret_node.typed_node.type

    @assert ret_type <: ASTValueType || ret_type == ASTVoid

    state.glsl_node = ret_type <: ASTValueType ? GLSLReturn(ret_node) : GLSLReturn(nothing)
end

function glsl_transform!(state::GLSLTransformState, ::Type{DeclTag}, ctx::GTContext)
    state.glsl_node = GLSLEmptyNode()
end

function glsl_transform_if!(state::GLSLTransformState, ctx::GTContext)
    tnode = state.typed_node
    expr = tnode.original[]

    @assert expr.head == :if || expr.head == :elseif
    @assert 2 <= length(expr.args) <= 3

    if tnode.children[1].type != ASTBool
        ast_error(expr, "If or elseif condition doesn't resolve to a bool value")
    end

    @assert expr.args[2] isa Expr && expr.args[2].head == :block
    @assert length(expr.args) != 3 || (expr.args[3] isa Expr && expr.args[3].head in [:block, :elseif])

    condition = GLSLTransformState(tnode.children[1])
    glsl_transform!(condition, ctx)

    body = GLSLTransformState(tnode.children[2])
    glsl_transform!(body, ctx)
    @assert body.glsl_node isa GLSLBlock

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
        @assert last_branch.glsl_node isa GLSLBlock
        state.glsl_node = GLSLIf(condition.glsl_node, body.glsl_node, Vector(), last_branch.glsl_node)
    end
end

has_nested_elseif(if_node::GLSLIf) = !isempty(if_node.elseif_branches) && !isempty(if_node.elseif_branches[end].elseif_branches)

function flatten_if!(if_node::GLSLIf)
    while has_nested_elseif(if_node)
        nested_elseif = if_node.elseif_branches[end]

        @assert length(nested_elseif.elseif_branches) == 1
        nested_branch = nested_elseif.elseif_branches[1]

        push!(if_node.elseif_branches, nested_branch)
        nested_elseif.elseif_branches = Vector()
    end

    for elseif_branch in if_node.elseif_branches
        if elseif_branch.condition isa GLSLBlock
            @assert length(elseif_branch.condition.body) == 1
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
        @assert isempty(if_node.elseif_branches)
        @assert isnothing(if_node.else_branch)
        @assert !(if_node.condition isa GLSLBlock)
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

    @assert length(state.children) == 2
    @assert state.children[1].typed_node.type == ASTBool
    @assert state.children[2].glsl_node isa GLSLBlock

    state.glsl_node = GLSLWhile(state.children[1].glsl_node, state.children[2].glsl_node)
end

function glsl_transform!(state::GLSLTransformState, ::Type{ForTag}, ctx::GTContext)
    tnode = state.typed_node

    @assert length(tnode.children) == 2

    it = tnode.children[1]
    body = tnode.children[2]

    body_state = GLSLTransformState(body)
    glsl_transform!(body_state, ctx)


end

function glsl_transform!(state::GLSLTransformState, ::Type{SwizzleTag}, ctx::GTContext)
    transform_children!(state, ctx, 1, 1)

    @assert state.children[1].typed_node.type <: ASTVec

    swizzle = state.typed_node.children[2].original[]
    @assert swizzle isa String

    state.glsl_node = GLSLSwizzle(state.children[1].glsl_node, swizzle)
end
