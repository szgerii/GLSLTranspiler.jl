function run_glsl_preprocessor(mod::Module, pipeline_ctx::GLSLPipelineContext, ast::Expr)
    @debug_assert ast.head == :function

    fdecl = ast.args[1]
    @debug_assert fdecl isa Expr && fdecl.head == :call

    for param in fdecl.args
        if param isa Expr && param.head == :decl
            if any(qualifier -> qualifier isa Union{InQualifier,OutQualifier,UniformQualifier}, param.args[4])
                push!(pipeline_ctx.env_syms, (param.args[1].value, param.args[2]))
            end
        end
    end

    fbody = ast.args[2]
    @debug_assert fbody isa Expr && fbody.head == :block

    ast.args[2] = glsl_preprocess(fbody, mod, pipeline_ctx)

    ast
end
