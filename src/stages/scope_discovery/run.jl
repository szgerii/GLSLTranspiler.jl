# AST -> Scoped AST + scope tree
function run_sd(mod::Module, _::PipelineContext, f::Expr)
    # create context for SAST construction  
    ctx = SDContext(mod)

    scoped_ast_root = sd_traverse(f, ctx)

    (scoped_ast_root, ctx.root_scope)
end
