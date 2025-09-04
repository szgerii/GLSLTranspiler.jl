function run_glsl_preprocessor(mod::Module, pipeline_ctx::GLSLPipelineContext, ast::Expr)
    @assert ast.head == :function

    fdecl = ast.args[1]
    @assert fdecl isa Expr && fdecl.head == :call

    for param in fdecl.args
        if param isa Expr && param.head == :decl
            if any(qualifier -> qualifier isa Union{InQualifier,OutQualifier,UniformQualifier}, param.args[4])
                push!(pipeline_ctx.env_syms, (param.args[1].value, param.args[2]))
            end
        end
    end

    shader_ctx = GLSLShaderContext()

    fbody = ast.args[2]
    @assert fbody isa Expr && fbody.head == :block

    ast.args[2] = glsl_preprocess(fbody, mod, pipeline_ctx)

    pipeline_ctx.shader_ctx = shader_ctx

    ast
end
