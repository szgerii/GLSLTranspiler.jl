export @build_tast

# asserts are things i assume to be true regarding the structure of function definition expressions 
# errors are for invalid expression inputs caused by user error

macro build_tast(f::Expr, detailed_info=false)
    f.head == :function || ast_error(f, "Attempting to use @build_tast for a non-function expression")

    @assert length(f.args) > 0
    @assert f.args[2].head == :block

    original_f = deepcopy(f)

    println("Original AST:")
    print_ast(f)
    println()

    Base.remove_linenums!(f)

    f = preprocess_ast(f, __module__)

    if detailed_info
        println("Preprocessed AST:")
        print_ast(f)
        println()
    end

    st = ScopeTree()
    fscope = get_fn_scope(st)

    fdecl = f.args[1]
    fname = fdecl.args[1]

    for param_decl in fdecl.args[2:end]
        @assert isa(param_decl, Expr)

        if param_decl.head != :(::)
            ast_error(f,
                "Cannot use @build_tast for a method without explicit parameter types (param $param_decl of a method for function $fname)")
        end

        pname = string(param_decl.args[1])
        src_type = eval(param_decl.args[2])
        tast_type = to_tast(src_type)

        isnothing(tast_type) && ast_error(f,
            "Invalid method parameter type: $src_type (for parameter $pname)")

        fscope.vars[pname] = VarData(pname, tast_type)
    end

    fbody = f.args[2]

    # bottom-up traversal of AST to determine expr types
    root = Ref(f)
    typed_ast = TypeTree(root)
    for child in fbody.args
        child_node = traverse_node(child, __module__, fscope, st)

        push!(typed_ast.children, child_node)
    end

    last_expr_type = typed_ast.children[end].type

    if haskey(fscope.vars, "%return")
        rtype = fscope.vars["%return"].type
        (last_expr_type != rtype) && ast_error(f,
            "Invalid last statement in function: last statement's type ($last_expr_type) doesn't match the function's previously inferred return type ($rtype)")
    else
        !(last_expr_type in literal_node_types || last_expr_type == TASTVoid) && ast_error(f,
            "Invalid last statement in function: the function's return type cannot be what is being inferred from the last statement ($last_expr_type)")
        fscope.vars["%return"] = VarData("%return", last_expr_type)
    end

    typed_ast.type = fscope.vars["%return"].type

    println("Generated typed AST:")
    print_tast(typed_ast)
    println()

    println("Determined scope structure:")
    print_scope_tree(st)

    println("\nDetected uniforms:")
    for (key, var_data) in st.glob[].vars
        println("$key : ", var_data.type)
    end

    :($(esc(original_f)))
end

# Expression nodes
function traverse_node(node::Expr, mod::Module, scope::Scope, scope_tree::ScopeTree)::TypeTree
    tag = tag_match(TASTNodeTag, node)

    if tag == TASTUnsupportedTag
        ast_error(node, "Unsupported expression type: $(node.head)")
    end

    node_ref = Ref(node)
    gen_node = TypeTree(node_ref)

    # TODO fn, do, let, comprehensions, generators
    if node.head in [:while, :for]
        child_scope = Scope(Ref(scope), SOFT_SCOPE)
        scope = child_scope
    end

    for child in node.args
        child_node = traverse_node(child, mod, scope, scope_tree)
        push!(gen_node.children, child_node)
    end

    gen_node = tast_transform(tag, gen_node, mod, scope, scope_tree)

    gen_node
end

# Symbol nodes
function traverse_node(node::Symbol, mod::Module, scope::Scope, scope_tree::ScopeTree)::TypeTree
    tast_type = nothing

    # search in determined type array...
    vdata = get_var_data(string(node), scope)
    if !isnothing(vdata)
        tast_type = vdata.type
    end

    # ...then in the calling module's scope
    if isnothing(tast_type) && isdefined(mod, node)
        vname = string(node)
        tast_type = to_tast(typeof(@eval mod $node))

        if tast_type <: TASTLiteral
            scope_tree.glob[].vars[vname] = VarData(vname, tast_type)
        end
    end

    node_ref = Ref(node)

    # if we found it in either, mark it as that type
    if !isnothing(tast_type)
        return TypeTree(tast_type, node_ref)
    end

    # if we didn't, mark it as a void_sym (an undefined symbol)
    # we dont error here, as it could still be part of a valid expression (e.g. value assignment lhs)
    TypeTree(TASTVoidSym, node_ref)
end

# Literal nodes
function traverse_node(node::ASTLiteral, _::Module, _::Scope, _::ScopeTree)::TypeTree
    src_type = typeof(node)
    tast_type = to_tast(src_type)

    isnothing(tast_type) && ast_error(node, "Unsupported literal type: $src_type (for literal $node)")

    node_ref = Ref(node)
    TypeTree(tast_type, node_ref)
end
