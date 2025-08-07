function run_tast(
    mod::Module, scoped_ast::ScopedASTNode,
    root_scope::Ref{Scope}, usyms::Vector{UniqueSymbol}, usym_table::ScopedUSymMapping
)
    fdecl = scoped_ast.children[1].original[]

    for param_decl in fdecl.args[2:end]
        if !(param_decl isa Expr)
            ast_error(scoped_ast.original[], "Couldn't transpile function without explicitly typed parameter '$param_decl'")
        end

        if param_decl.head != :(::)
            ast_error(param_decl, "Unsupported parameter declaration")
        end

        pname = string(param_decl.args[1])
        src_type = eval(param_decl.args[2])
        tast_type = to_tast(src_type)

        isnothing(tast_type) && ast_error(f,
            "Invalid method parameter type: $src_type (for parameter $pname)")

        fscope.vars[pname] = VarData(pname, tast_type)
    end

    fbody = f.args[2]

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

    return (typed_ast)
end

# Expression nodes
function traverse_node(node::Expr, mod::Module, scope::Scope)::TypeTree
    tag = tag_match(TASTNodeTag, node)

    tag == TASTUnsupportedTag && ast_error(node, "Unsupported expression type: $(node.head)")

    node_ref = Ref(node)
    gen_node = TypeTree(node_ref)

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
