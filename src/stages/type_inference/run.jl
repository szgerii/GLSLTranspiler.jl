using ..GLSLTranspiler: ast_error, print_traverse

function run_type_inference(
    mod::Module, scoped_ast::ScopedASTNode,
    root_scope::Ref{Scope}, usyms::Vector{UniqueSymbol}, usym_table::ScopedUSymMapping
)
    ctx = TIContext(mod, root_scope, map(usym -> (usym, nothing), usyms), usym_table, Nothing)

    fdecl = scoped_ast.children[1].original[]

    fname = fdecl.args[1]
    add_type!(ctx, get_usym_id(fname, FUNCTION_SCOPE_ID), ASTFunction)

    for param_decl in fdecl.args[2:end]
        if !(param_decl isa Expr)
            ast_error(scoped_ast.original[], "Couldn't transpile function without explicitly typed parameter '$param_decl'")
        end

        if param_decl.head != :(::)
            ast_error(param_decl, "Unsupported parameter declaration")
        end

        name_sym = param_decl.args[1]
        type_sym = param_decl.args[2]

        @assert name_sym isa Symbol
        @assert type_sym isa Symbol

        pname = string(name_sym)
        src_type = mod.eval(type_sym)
        tast_type = to_tast(src_type)

        if isnothing(tast_type)
            ast_error(param_decl, "Invalid method parameter type: $src_type (for parameter $pname)")
        end

        target_usym_id = get_usym_id(name_sym, FUNCTION_SCOPE_ID)
        idx = find_usym_index(target_usym_id, ctx)

        if isnothing(idx)
            ast_error(param_decl, "Unique symbol for param $name_sym was not found in the output of the symbol resolution stage")
        end

        add_type!(ctx, target_usym_id, tast_type)
    end

    typed_ast = TypedASTNode(scoped_ast)

    # clone fn declaration sub-tree without type inference
    push!(typed_ast.children, clone_subtree(scoped_ast.children[1]))

    # transform fn body sub-tree from scoped ast into typed ast
    push!(typed_ast.children, gen_typed_ast(scoped_ast.children[2], ctx))

    last_expr = typed_ast.children[2].children[end]

    if ctx.return_type != Nothing
        if last_expr.type != ctx.return_type
            ast_error(last_expr.original[],
                "Invalid last statement in function: last statement's type ($(last_expr.type)) doesn't match the function's previously inferred return type ($rtype)")
        end
    else
        if !(last_expr.type <: ASTValueType || last_expr.type == ASTVoid)
            ast_error(last_expr.original[],
                "Invalid last statement in function: the function's return type cannot be what is being inferred from the last statement ($(last_expr.type))")
        end

        ctx.return_type = last_expr.type
    end

    typed_ast.children[2].type = ctx.return_type
    typed_ast.type = ctx.return_type

    println("\nUSym Types:")
    for (usym, type) in ctx.typed_usyms
        println(usym.id, " => ", type)
    end
    println()

    return (typed_ast)
end

function clone_subtree(root::ScopedASTNode)::TypedASTNode
    if !(root.original[] isa Expr)
        return TypedASTNode(root)
    end

    typed_node = TypedASTNode(root)

    for child in root.children
        push!(typed_node.children, clone_subtree(child))
    end

    typed_node
end
