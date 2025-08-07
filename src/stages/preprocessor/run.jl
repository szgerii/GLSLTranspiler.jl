# AST -> AST
function run_preprocessor(mod::Module, f::Expr)::Expr
    # run preprocessor only on fn body
    f.args[2] = preprocess_traverse(f.args[2], mod)

    f
end
