"""
    infer_typed_ast_node!(node::TypedASTNode, ::Type{T}, ctx::TIContext) where {T <: TASTNodeTag}

Determine the type of `node` and fill its type information accordingly.
"""
infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTDefault}, _::TIContext) = node

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTAssignmentTag}, ctx::TIContext)
    @debug_assert length(node.children) == 2

    lhs = node.children[1]
    rhs = node.children[2]
    
    vname = string(lhs.original[])
    
    if is_ast_void(rhs.type)
        ast_error(node.original[],
            "Couldn't determine right side type of assignment expression. This might be the result of using an unsupported Julia feature.")
    end

    target_type = rhs.type
    
    if lhs.type == ASTVoidSym
        # a new symbol is being defined
        @debug_assert isnothing(find_type(lhs.original[], ctx))

        if rhs.type <: ASTListLiteral
            n = length(rhs.type)
            t = eltype(rhs.type)

            target_type = ASTList{n, t}
        end

        add_type!(ctx, lhs.original[], target_type)
    elseif (lhs.type != rhs.type)
        if lhs.type <: ASTList && rhs.type <: ASTListLiteral
            arr_n = length(lhs.type)
            arr_t = eltype(lhs.type)
            lit_n = length(rhs.type)
            lit_t = eltype(rhs.type)

            if (0 < arr_n != lit_n)
                ast_error(node.original[],
                    "List literal assignment dimension mismatch: trying to assign list literal of length $lit_n to list of length $arr_n")
            end

            if arr_t != lit_t
                ast_error(node.original[],
                    "List literal assignment type mismatch: trying to assign list literal with element type $lit_t to list with element type $arr_t")
            end

            target_type = lhs.type
        elseif !(is_i32_i64_swap_allowed(ctx.pipeline_ctx) && all(n -> n.type <: Union{ASTInt32, ASTInt64}, [lhs, rhs]))
            # TODO: allow this through typed usyms
            ast_error(node.original[],
                "Reassignment to new type: Trying to bind variable '$vname' of type '$(lhs.type)' to a value of type '$(rhs.type)'.")
        end
    end

    node.type = target_type
end

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTModuleResolveTag}, ctx::TIContext)
    @debug_assert node.children[1].type == ASTModule

    target = resolve_module_chain(node.original[], ctx.defining_module)
    src_type = ctx.defining_module.eval(:(typeof($target)))
    tast_type = to_tast(src_type)

    node.type = tast_type
end

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTCallTag}, ctx::TIContext)
    fsym = node.children[1]
    args = node.children[2:end]

    @debug_assert fsym.original[] isa Symbol || (fsym.original[] isa Expr && fsym.original[].head == :(.))

    sym_ref = fsym.original[] isa Symbol
    is_helper = sym_ref && has_helper(ctx.pipeline_ctx, fsym.original[])

    if sym_ref
        if fsym.original[] == :(/) && length(args) >= 2
            arg_type = args[1].type

            if all(T -> arg_type == T, args[2:end])
                node.type = arg_type
                return
            end
        end

        if fsym.original[] == :length && length(args) == 1 && args[1].type <: Union{ASTList,ASTListLiteral}
            node.type = ASTInt32
            return
        end

        arg_types = map(arg -> arg.type, args)
        ret = builtin_fn_ret_type(ctx.pipeline_ctx, Val(fsym.original[]), arg_types...)
        if !ismissing(ret)
            @debug_assert ret <: ASTType "Invalid return type for environment function $(fsym.original[]) called with args $(arg_types)"

            node.type = ret
            return
        end
    end

    first_arg_idx = 1

    if fsym.original[] == :broadcast
        @debug_assert args[1].type == ASTFunction
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

    if sym_ref && !has_helper(ctx.pipeline_ctx, fsym.original[]) && !isdefined(ctx.defining_module, fsym.original[])
        ast_error(node.original[],
            "Couldn't find function '$(fsym.original[])' in the definition's module, the helper function list or in the built-in function list.")
    end

    args_tuple = Tuple(map(arg -> to_ast(arg.type), args[first_arg_idx:end]))

    if is_helper
        tast_args_tuple = map(T -> to_tast(T), args_tuple)
        @debug_assert !any(isnothing, tast_args_tuple)

        rtype = get_helper_ret_type(ctx.pipeline_ctx, fsym.original[], tast_args_tuple)

        if !ismissing(rtype)
            @debug_assert rtype <: ASTType

            node.type = rtype
            return
        else
            println("WARNING: Possible missed function call to local function $(fsym.original[]).\n",
                "Function was called with type signature $(tast_args_tuple), which is not a valid signature for the function.")
        end
    end

    f = sym_ref ?
        getfield(ctx.defining_module, fsym.original[]) :
        resolve_module_chain(fsym.original[], ctx.defining_module)

    if fsym.original[] == :broadcast
        f_type = ctx.defining_module.eval(:(typeof($(args[1].original[]))))
        args_tuple = (f_type, args_tuple...)
    end

    if !hasmethod(f, args_tuple)
        ast_error(node.original[],
            "No method found for call to $f with arguments of type $args_tuple")
    end

    rtypes = collect(Set(Base.return_types(f, args_tuple)))

    node.type = Missing
    if length(rtypes) == 0 || (rtypes == [Nothing])
        node.type = ASTVoid
    elseif length(rtypes) == 1
        if rtypes[1] in [Union{}, Any]
            ct = Base.code_typed(f, args_tuple; optimize=false, debuginfo=:none)
            @debug_assert length(ct) == 1

            rtypes[1] = ct[1].second
        end

        if !(rtypes[1] in [Union{}, Any])
            # clear return type
            tast_type = to_tast(rtypes[1])

            if isnothing(tast_type)
                ast_error(node.original[], "Function $f returns invalid type: ", rtypes[1])
            end

            node.type = tast_type
        end
    end

    if node.type == Missing
        ast_error(node.original[],
            "Couldn't clearly infer return type for function $f called with arguments of type $args_tuple, possible return types are: $rtypes")
    end
end

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTReturnTag}, ctx::TIContext)
    rtype = node.children[1].type

    if rtype != ASTVoid && !get_in_helper(ctx.pipeline_ctx)
        ast_error(node.original[], "Found non-empty return statement in the main function's body")
    end

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
    @debug_assert length(node.original[].args) == 3

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
    coll_type = node.children[1].type
    if coll_type <: ASTVec # swizzle or vec indexing
        handle_vec_index!(node)
    elseif coll_type <: ASTMat # mat indexing
        handle_mat_index!(node)
    elseif coll_type <: ASTList
        handle_arr_index!(node)
    else
        ast_error(node.original[], "Trying to index into unsupported type: $(coll_type)")
    end
end

function handle_vec_index!(node::TypedASTNode)
    vec_node = node.children[1]
    el_type = eltype(vec_node.type)
    el_count = length(vec_node.type)

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
            @debug_assert !isnothing(node.type) "Invalid element type $el_type in vector type $(vec_node.type)"
        elseif 2 <= new_len <= 4
            node.type = get_ast_vec_type(el_type, new_len)
        else
            error("Invalid swizzle length in swizzle $idx for $(vec_node.original[])")
        end
    elseif idx isa Integer
        # regular indexing
        @debug_assert idx <= el_count "Index out of bounds: attempting to access component $idx of $(vec_node.type)"

        node.type = to_tast(el_type)
        @debug_assert !isnothing(node.type) "Invalid element type $el_type for vector type $(vec_node.type)"
    else
        ast_error(node.original[],
            "Unsupported or invalid index type provided for vector indexing: $(node.children[2].type)")
    end
end

function handle_mat_index!(node::TypedASTNode)
    node.type = ASTVoid

    mat_node = node.children[1]
    el_type = eltype(mat_node.type)
    (n, m) = size(to_ast(mat_node.type))

    @debug_assert 2 <= n <= 4 && 2 <= m <= 4

    indices = node.children[2:end]

    if length(indices) == 1
        # indexes specifying a concrete element
        idx = indices[1]

        if is_ast_integer(idx.type)
            node.type = to_tast(el_type)
            @debug_assert !isnothing(node.type)
        end
    elseif length(indices) == 2
        # indexes specifying row and col
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
            @debug_assert !isnothing(node.type)
        end
    end

    if node.type == ASTVoid
        ast_error(node.original[], "Couldn't determine type for indexer into matrix type $(mat_node.type). This may be the result of using an unsupported indexer format.")
    end
end

function handle_arr_index!(node::TypedASTNode)
    @debug_assert length(node.children) == 2 "Invalid number of indexer arguments for array indexing"
    
    arr_node = node.children[1]
    idx_node = node.children[2]
    idx = idx_node.original[]

    if !(idx_node.type <: Union{ASTInt32,ASTInt64,ASTUInt32,ASTUInt64})
        ast_error(node.original[], "Invalid indexer type used for array indexing: $(idx_node.type). Only integer types are supported.")
    end

    # bounds checking for literal indexes
    if idx isa ASTLiteral
        n = length(arr_node.type)
        
        # we keep 1-based indexing here (core pipeline aims to stay close to Julia for now)
        if n > 0 && idx > n || idx < 1
            ast_error(node.original[], "Index out of bounds error for literal index '$(idx)' into array '$(arr_node.original[])' of size $n.")
        end
    end

    node.type = eltype(arr_node.type)
end

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTVectLiteralTag}, ctx::TIContext)
    # eltype cannot be easily inferred for empty array literals
    if length(node.children) == 0
        ast_error(node.original[], "Empty literals are not supported")
    end

    arr_lit = node.original[].args

    arr_n = length(arr_lit)
    arr_t = typeof(arr_lit[1])

    if any(el -> typeof(el) != arr_t, arr_lit)
        ast_error(node.original[],
            "Invalid array literal, elements are of different types in:\n" *
            "[" * join(arr_lit, ",") * "]"
        )
    end

    arr_t = to_tast(arr_t)

    if isnothing(arr_t)
        ast_error(node.original[],
            "Invalid element type '$arr_t' found in array literal: $(join(arr_lit, ","))."
        )
    end

    node.type = ASTListLiteral{arr_n, arr_t}
end

precomp_subtypes(TASTNodeTag, infer_typed_ast_node!, (TypedASTNode, missing, TIContext))
