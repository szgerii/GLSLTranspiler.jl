using ..GLSLTranspiler: ast_error

infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTDefault}, _::TIContext) = node

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTAssignmentTag}, ctx::TIContext)
    @assert length(node.children) == 2

    lhs = node.children[1]
    rhs = node.children[2]

    vname = string(lhs.original[])

    if is_void(rhs.type)
        ast_error(node.original[],
            "Couldn't determine right side type of assignment expression. This might be the result of using an unsupported Julia feature.")
    end

    if lhs.type == ASTVoidSym
        # a new symbol is being defined
        @assert isnothing(find_type(lhs.original[], ctx))

        add_type!(ctx, lhs.original[], rhs.type)
    elseif lhs.type != rhs.type
        # TODO: allow this through typed usyms
        ast_error(node.original[],
            "Reassignment to new type: Trying to bind variable '$vname' of type '$(lhs.type)' to a value of type '$(rhs.type)'.")
    end

    node.type = rhs.type
end

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTModuleResolveTag}, ctx::TIContext)
    @assert node.children[1].type == ASTModule

    target = resolve_module_chain(node.original[], ctx.defining_module)
    src_type = ctx.defining_module.eval(:(typeof($target)))
    tast_type = to_tast(src_type)

    node.type = tast_type
end

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTCallTag}, ctx::TIContext)
    fsym = node.children[1]
    args = node.children[2:end]

    @assert fsym.original[] isa Symbol || (fsym.original[] isa Expr && fsym.original[].head == :(.))

    sym_ref = fsym.original[] isa Symbol

    if sym_ref
        arg_types = map(arg -> arg.type, args)
        ret = builtin_fn_ret_type(ctx.pipeline_ctx, Val(fsym.original[]), arg_types...)
        if !ismissing(ret)
            @assert ret <: ASTType "Invalid return type for environment function $(fsym.original[]) called with args $(arg_types)"

            node.type = ret

            return
        end
    end

    first_arg_idx = 1

    if fsym.original[] == :broadcast
        @assert args[1].type == ASTFunction
        first_arg_idx = 2
    elseif fsym.type != ASTFunction
        ast_error(node.original[],
            "Trying to call a symbol that is not a function ($(fsym.original[]) isa $(fsym.type))\n",
            "Argument types are: ", arg_types)
    end

    for arg in args[first_arg_idx:end]
        if !(arg.type <: ASTValueType)
            ast_error(node.original[],
                "Invalid value type in '$(fsym.original[])' function call argument: $(arg.type)")
        end
    end

    if sym_ref && !isdefined(ctx.defining_module, fsym.original[])
        ast_error(node.original[],
            "Couldn't find function '$(fsym.original[])' in the definition's module or in the environment function list.")
    end

    f = sym_ref ? getfield(ctx.defining_module, fsym.original[]) : resolve_module_chain(fsym.original[], ctx.defining_module)
    args_tuple = Tuple(map(arg -> to_ast(arg.type), args[first_arg_idx:end]))

    if fsym.original[] == :broadcast
        f_type = ctx.defining_module.eval(:(typeof($(args[1].original[]))))
        args_tuple = (f_type, args_tuple...)
    end

    if !hasmethod(f, args_tuple)
        ast_error(node.original[],
            "No method found for call to $f with arguments of type $args_tuple")
    end

    rtypes = collect(Set(Base.return_types(f, args_tuple)))

    if length(rtypes) == 0 || (rtypes == [Nothing])
        node.type = ASTVoid
    elseif length(rtypes) == 1
        if rtypes[1] in [Union{}, Any]
            println(f)
            println(args_tuple)
            ct = Base.code_typed(f, args_tuple; optimize=false, debuginfo=:none)
            println(ct)
            @assert length(ct) == 1

            rtypes[1] = ct[1].second
        end

        @assert !(rtypes[1] in [Union{}, Any])

        # clear return type
        tast_type = to_tast(rtypes[1])

        if isnothing(tast_type)
            ast_error(node.original[], "Function $f returns invalid type: ", rtypes[1])
        end

        node.type = tast_type
    else
        # TODO maybe infer from code_typed
        ast_error(node.original[],
            "Couldn't clearly infer return type for function $f called with arguments of type $args_tuple, possible return types are: $rtypes")
    end
end

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTReturnTag}, ctx::TIContext)
    rtype = node.children[1].type

    if ctx.return_type != Nothing
        if ctx.return_type != rtype
            ast_error(node.original[],
                "Conflicting return types inferred for the transpilation's input function")
        end
    elseif !(rtype <: ASTValueType || rtype == ASTVoid)
        ast_error(node.original[],
            "Invalid return statement: the type being inferred from the return statement is not a valid return type ($rtype)")
    else
        ctx.return_type = rtype
    end

    node.type = rtype
end

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTTernaryTag}, ctx::TIContext)
    @assert length(node.original[].args) == 3

    t1 = node.children[2].type
    t2 = node.children[3].type

    if t1 != t2
        ast_error(node.original[],
            "Invalid ternary operator: The different branches resolve to different return types ($t1 and $t2)")
    end

    node.type = t1
end

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTBlockTag}, ctx::TIContext)
    node.type = length(node.children) > 0 ? node.children[end].type : ASTVoid
end

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTLogicalChainTag}, ctx::TIContext)
    for arg in node.children
        if arg.type != ASTBool
            ast_error(node,
                "Found invalid type in a logical chaining operator's arguments. Expected ASTBool, got $(arg.type) instead.")
        end
    end

    node.type = ASTBool
end

const swizzle_groups = ["xyzw", "rgba", "stpq"]

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTRefTag}, ctx::TIContext)
    if node.children[1].type <: ASTVec
        handle_vec_index!(node, ctx)
    elseif node.children[1].type <: ASTMat
        handle_mat_index!(node, ctx)
    else
        ast_error(node.original[], "Trying to index into unsupported type: $(node.children[1].type)")
    end
end

function handle_vec_index!(node::TypedASTNode, _::TIContext)
    vec_node = node.children[1]
    el_type = eltype(vec_node.type)
    el_count = elcount(vec_node.type)

    if length(node.children) < 2
        ast_error(node.original[], "Trying to dereference a vector ($(vec_node.type))")
    elseif length(node.children) > 2
        ast_error(node.original[], "Multi-argument vector indexing is not supported")
    end

    # single-argument indexing
    idx = node.children[2].original[]

    if idx isa QuoteNode
        idx = idx.value
    end

    if idx isa Symbol
        idx = string(idx)

        node.children[2].original = Ref(idx)
        node.children[2].type = ASTString
    end

    if idx isa String
        # swizzle
        swizzle_group = nothing
        for group in swizzle_groups
            if all(char -> char in group, idx)
                swizzle_group = group
                break
            end
        end

        if isnothing(swizzle_group)
            ast_error(
                node.original[],
                "Invalid swizzle indexer: $idx\n",
                "This might be because of invalid swizzle coordinates or using coordinates from different groups"
            )
        end

        swizzle_reach = maximum(char -> findfirst(char, swizzle_group), idx)

        if swizzle_reach > el_count
            ast_error(node.original[],
                "Trying to access component $(swizzle_reach) of Vec$(el_count)"
            )
        end

        new_len = length(idx)

        if new_len == 1
            node.type = to_tast(el_type)
            @assert !isnothing(node.type) "Invalid element type $el_type in vector type $(vec_node.type)"
        elseif 2 <= new_len <= 4
            node.type = get_ast_vec_type(el_type, new_len)
        else
            error("Invalid swizzle length in swizzle $idx for $(vec_node.original[])")
        end
    elseif idx isa Integer
        # regular indexing
        @assert idx <= el_count "Index out of bounds: attempting to access component $idx of $(vec_node.type)"

        node.type = to_tast(el_type)
        @assert !isnothing(node.type) "Invalid element type $el_type for vector type $(vec_node.type)"
    else
        ast_error(node.original[],
            "Unsupported or invalid index type provided for vector indexing: $(node.children[2].type)")
    end
end

function handle_mat_index!(node::TypedASTNode, _::TIContext)
    node.type = ASTVoid

    mat_node = node.children[1]
    el_type = eltype(mat_node.type)
    (n, m) = size(to_ast(mat_node.type))

    @assert 2 <= n <= 4 && 2 <= m <= 4

    indices = node.children[2:end]

    if length(indices) == 1
        idx = indices[1]

        if is_ast_integer(idx.type)
            node.type = to_tast(el_type)
            @assert !isnothing(node.type)
        end
    elseif length(indices) == 2
        row_idx = indices[1]
        col_idx = indices[2]
        row_orig = row_idx.original[]
        col_orig = col_idx.original[]

        if row_orig == :(:) && col_orig == :(:)
            node.type = mat_node.type
        elseif row_orig == :(:) && is_ast_integer(col_idx.type)
            node.type = get_ast_vec_type(el_type, m)
        elseif col_orig == :(:) && is_ast_integer(row_idx.type)
            node.type = get_ast_vec_type(el_type, n)
        elseif is_ast_integer(col_idx.type) && is_ast_integer(row_idx.type)
            node.type = to_tast(el_type)
            @assert !isnothing(node.type)
        end
    end

    if node.type == ASTVoid
        ast_error(node.original[], "Couldn't determine type for indexer into matrix type $(mat_node.type). This may be the result of using an unsupported indexer format.")
    end
end

precomp_subtypes(TASTNodeTag, infer_typed_ast_node!, (TypedASTNode, missing, TIContext))
