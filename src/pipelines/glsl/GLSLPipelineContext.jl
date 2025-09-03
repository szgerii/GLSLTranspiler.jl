export GLSLPipelineContext

mutable struct GLSLPipelineContext <: PipelineContext
    shader_ctx::Union{GLSLShaderContext,Missing}
    env_syms::GLSLVarList
    def_transform::Union{Function,Nothing,Missing}
end

function remove_env_sym_decls!(f::Expr, pipeline_ctx::GLSLPipelineContext)
    body = f.args[2]
    env_syms = get_env_syms(pipeline_ctx)

    i = 1
    while i <= length(body.args) && body.args[i] isa Expr && body.args[i].head == :local
        sym = body.args[i].args[1]
        @assert sym isa Symbol

        if sym in env_syms
            popat!(body.args, i)
        else
            i += 1
        end
    end
end

const gl_vars = [
    (:gl_Position, Vec4),
    (:gl_FragCoord, Vec4)
]

CoreTypes.init_pipeline_ctx(::Type{GLSLPipelineContext}) = GLSLPipelineContext(missing, deepcopy(gl_vars), remove_env_sym_decls!)

CoreTypes.get_def_transform(ctx::GLSLPipelineContext) = ctx.def_transform

CoreTypes.get_env_syms(ctx::GLSLPipelineContext) = map(var -> var[1], ctx.env_syms)

function CoreTypes.get_env_sym_type(sym::Symbol, ctx::GLSLPipelineContext)
    idx = findfirst(var -> var[1] == sym, ctx.env_syms)

    !isnothing(idx) ? ctx.env_syms[idx][2] : nothing
end
