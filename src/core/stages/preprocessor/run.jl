# AST -> AST
function run_preprocessor(mod::Module, _::PipelineContext, ast::Expr)::Expr
    for (i, param) in enumerate(ast.args[1].args)
        if param isa Expr && param.head == :decl
            ast.args[1].args[i].args[3] = :param
        end
    end

    # run preprocessor only on fn body
    result = preprocess_traverse(ast.args[2], mod)
    @debug_assert length(result) == 1
    ast.args[2] = result[1]

    ast
end
