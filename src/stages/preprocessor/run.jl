# AST -> AST
function run_preprocessor(mod::Module, _::PipelineContext, ast::Expr)::Expr
    # run preprocessor only on fn body
    result = preprocess_traverse(ast.args[2], mod)
    @assert length(result) == 1
    ast.args[2] = result[1]

    ast
end
