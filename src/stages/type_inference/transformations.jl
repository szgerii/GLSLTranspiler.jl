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
            "Reassignment to new type: Trying to bind variable '$vname' of type '$(lhs.type)' to a value of type '$(rhs.type)'. This is not allowed for now, but support will be added later.")
    end

    node.type = rhs.type
end

function infer_typed_ast_node!(node::TypedASTNode, ::Type{TASTCallTag}, ctx::TIContext)
    fsym = node.children[1]
    args = node.children[2:end]

    if fsym.type != ASTFunction
        ast_error(node.original[],
            "Trying to call a symbol that is not a function ($(fsym.original[]) isa $(fsym.type))")
    end

    for arg in args
        if !(arg.type <: ASTValueType)
            ast_error(node.original[],
                "Trying to use a value for a function argument whose type could not be inferred")
        end
    end

    f = getproperty(ctx.defining_module, fsym.original[])
    args_tuple = Tuple(map(arg -> to_ast(arg.type), args))

    if !hasmethod(f, args_tuple)
        ast_error(node.original[],
            "No method found for call to $f with arguments of type $args_tuple")
    end

    rtypes = collect(Set(Base.return_types(f, args_tuple)))

    if length(rtypes) == 0 || (rtypes == [Nothing])
        node.type = ASTVoid
    elseif length(rtypes) == 1 && rtypes[1] != Union{}
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
                "Found invalid type in a logical chaining operator's argument. Expected ASTBool, got $(arg.type) instead.")
        end
    end

    node.type = ASTBool
end
