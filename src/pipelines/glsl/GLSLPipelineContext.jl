export GLSLPipelineContext

mutable struct GLSLPipelineContext <: PipelineContext
    shader_ctx::Union{GLSLShaderContext,Missing}
end
