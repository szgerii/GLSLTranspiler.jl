tast_transform(::Type{TASTDefault}, node::TypeTree, _::Module, _::Scope, _::ScopeTree)::TypeTree = node

function tast_transform(::Type{TASTAssignmentTag}, node::TypeTree, mod::Module, scope::Scope, scope_tree::ScopeTree)::TypeTree
    @assert length(node.children) == 2

    lhs = node.children[1]
    rhs = node.children[2]

    vname = string(lhs.original[])

    rhs.type == TASTVoid && ast_error(node.original[],
        "Couldn't determine right side type of assignment expression. This might be the result of using an unsupported Julia feature.")

    if lhs.type == TASTVoidSym
        # a new symbol is being defined
        @assert !haskey(scope.vars, vname)

        scope.vars[vname] = VarData(vname, rhs.type)
    elseif lhs.type != rhs.type
        # TODO: allow this through numbered var names
        ast_error(node.original[],
            "Reassignment to new type: Trying to bind variable '$vname' of type '$(lhs.type)' to a value of type '$(rhs.type)'. This is not allowed for now, but support will be added later.")
    end

    node.type = rhs.type
    node
end

function tast_transform(::Type{TASTCallTag}, node::TypeTree, mod::Module, scope::Scope, scope_tree::ScopeTree)::TypeTree
    fsym = node.children[1]
    args = node.children[2:end]

    fsym.type != TASTFunction && ast_error(node.original[],
        "Trying to call a symbol that is not a function (", fsym.original[], ")")

    for arg in args
        !(arg.type <: TASTLiteral) && ast_error(node.original[],
            "Trying to use a value for a function argument whose type could not be inferred")
    end

    f = getproperty(mod, fsym.original[])
    args_tuple = Tuple(map(arg -> to_ast(arg.type), args))

    !hasmethod(f, args_tuple) && ast_error(node.original[],
        "No method found for call to $f with arguments of type $args_tuple")

    rtypes = collect(Set(Base.return_types(f, args_tuple)))

    if length(rtypes) == 0 || (length(rtypes) == 1 && rtypes[1] == Nothing)
        node.type = TASTVoid
    elseif length(rtypes) == 1 && rtypes[1] != Union{}
        # clear return type
        tast_type = to_tast(rtypes[1])
        isnothing(tast_type) && ast_error(node.original[],
            "Function $f returns invalid type: ", rtypes[1])

        node.type = tast_type
    else
        # TODO infer from code_typed
        ast_error(node.original[],
            "Couldn't clearly infer return type for function $f called with arguments of type $args_tuple, possible return types are: $rtypes")
    end

    node
end

function tast_transform(::Type{TASTReturnTag}, node::TypeTree, mod::Module, scope::Scope, scope_tree::ScopeTree)::TypeTree
    rtype = node.children[1].type
    fscope = get_fn_scope(scope_tree)

    if haskey(fscope.vars, "%return")
        if fscope.vars["%return"].type != rtype
            ast_error(node.original[],
                "Cannot use @build_ast for functions whose return type is not a single, static type")
        end
    elseif !(rtype <: TASTLiteral || rtype == TASTVoid)
        ast_error(node.original[],
            "Invalid return statement: the type being inferred from the return statement is not a valid return type ($rtype)")
    end

    fscope.vars["%return"] = VarData("%return", rtype)

    node.type = rtype
    node
end

function tast_transform(::Type{TASTIfTag}, node::TypeTree, mod::Module, scope::Scope, scope_tree::ScopeTree)::TypeTree
    @assert node.original[].args[2].head == :block
    @assert node.original[].args[3].head in [:block, :elseif]

    node
end

function tast_transform(::Type{TASTTernaryTag}, node::TypeTree, _::Module, _::Scope, _::ScopeTree)::TypeTree
    @assert length(node.original[].args) == 3

    t1 = node.children[2].type
    t2 = node.children[3].type

    t1 != t2 && ast_error(node.original[],
        "Invalid ternary operator: The different branches resolve to different return types ($t1 and $t2)")

    node.type = t1
    node
end

function tast_transform(::Type{TASTBlockTag}, node::TypeTree, mod::Module, scope::Scope, scope_tree::ScopeTree)::TypeTree
    node.type = length(node.children) > 0 ? node.children[end].type : TASTVoid
    node
end

function tast_transform(::Type{TASTLogicalChainTag}, node::TypeTree, _::Module, scope::Scope, scope_tree::ScopeTree)::TypeTree
    for arg in node.children
        arg.type != TASTBool && ast_error(node,
            "Found invalid type in a logical chaining operator's argument. Expected $TASTBool, got $(arg.type) instead.")
    end

    node.type = TASTBool
    node
end
