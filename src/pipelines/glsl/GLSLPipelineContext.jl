import ...GLSLTranspiler

export GLSLPipelineContext

mutable struct GLSLPipelineContext <: PipelineContext
    shader_ctx::Union{GLSLShaderContext,Missing}
    env_syms::GLSLVarList
end

const gl_vars = [
    (:gl_Position, GLSLTranspiler.Vec4),
    (:gl_FragCoord, GLSLTranspiler.Vec4),
]

BaseTypes.init_pipeline_ctx(::Type{GLSLPipelineContext}) = GLSLPipelineContext(missing, gl_vars)

function BaseTypes.get_env_syms(ctx::GLSLPipelineContext)
    map(var -> var[1], ctx.env_syms)
end

function BaseTypes.get_env_sym_type(sym::Symbol, ctx::GLSLPipelineContext)
    idx = findfirst(var -> var[1] == sym, ctx.env_syms)

    !isnothing(idx) ? ctx.env_syms[idx][2] : nothing
end
