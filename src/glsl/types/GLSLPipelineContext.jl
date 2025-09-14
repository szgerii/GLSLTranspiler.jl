export GLSLPipelineContext

const GLSLVarList = Vector{Tuple{Symbol,DataType}}

"""
    GLSLPipelineContext(env_syms, def_transform, helpers, helper_sigs, in_helper) <: PipelineContext

Stores context information for a GLSL pipeline transpilation.

# Fields
- `env_syms::Vector{Tuple{Symbol,DataType}}`: Stores the list of GLSL built-in variables and their types. It can also be expanded dynamically with other fixed type, fixed name global symbols during early pipeline stages.
- `def_transform::Union{Function,Nothing,Missing}`: The transformation function applied to the fn def [`Expr`](@ref) before saving it during pipeline execution (defaults to [`remove_env_sym_decls`](@ref))
- `helpers::Vector{Tuple{Expr,Any}}`: List for storing helper function pipeline outputs
- `helper_sigs::Dict{Tuple{Symbol,Tuple},DataType}`: Dictionary for looking up helper fn return types based on their name and signature
- `in_helper::Bool`: Indicates whether the current stage is being ran on a helper function or the main function
"""
mutable struct GLSLPipelineContext <: PipelineContext
    env_syms::GLSLVarList
    def_transform::Union{Function,Nothing,Missing}
    helpers::Vector{Tuple{Expr,Any}}
    helper_sigs::Dict{Tuple{Symbol,Tuple},DataType}
    in_helper::Bool
end

function remove_env_sym_decls!(f::Expr, pipeline_ctx::GLSLPipelineContext)
    body = f.args[2]
    env_syms = get_env_syms(pipeline_ctx)

    i = 1
    while i <= length(body.args) && body.args[i] isa Expr && body.args[i].head == :local
        sym = body.args[i].args[1]

        if sym isa Symbol && sym in env_syms
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

# The rest of the context is just implementing the general PipelineContext "interface"

CoreTypes.init_pipeline_ctx(::Type{GLSLPipelineContext}) =
    GLSLPipelineContext(deepcopy(gl_vars), remove_env_sym_decls!, Vector(), Dict(), false)

CoreTypes.get_def_transform(ctx::GLSLPipelineContext) = ctx.def_transform

CoreTypes.get_env_syms(ctx::GLSLPipelineContext) = map(var -> var[1], ctx.env_syms)

CoreTypes.add_helper!(ctx::GLSLPipelineContext, helper::Tuple{Expr,Any}) = push!(ctx.helpers, helper)
CoreTypes.get_helpers(ctx::GLSLPipelineContext) = ctx.helpers

CoreTypes.get_in_helper(ctx::GLSLPipelineContext) = ctx.in_helper
CoreTypes.set_in_helper!(ctx::GLSLPipelineContext, val::Bool) = (ctx.in_helper = val)

function CoreTypes.add_env_sym!(ctx::GLSLPipelineContext, name::Symbol, type::DataType)
    if any(es -> es[1] == name, ctx.env_syms)
        error("Trying to add already existing env sym to GLSL pipeline context: $name")
    end

    push!(ctx.env_syms, (name, type))
end

function CoreTypes.remove_env_sym!(ctx::GLSLPipelineContext, name::Symbol)
    idx = findfirst(es -> es[1] == name, ctx.env_syms)
    if isnothing(idx)
        error("Trying to remove non-existent env sym from GLSL pipeline context: $name")
    end

    popat!(ctx.env_syms, idx)
end

function CoreTypes.add_helper_ret_type!(ctx::GLSLPipelineContext, name::Symbol, sig::Tuple, ::Type{RetType}) where {RetType<:ASTType}
    key = (name, sig)

    if haskey(ctx.helper_sigs, key)
        error("Trying to define function $name with signature $sig multiple times")
    end

    ctx.helper_sigs[key] = RetType
end

CoreTypes.get_helper_ret_type(ctx::GLSLPipelineContext, name::Symbol, sig::Tuple) = get(ctx.helper_sigs, (name, sig), missing)

function CoreTypes.get_env_sym_type(sym::Symbol, ctx::GLSLPipelineContext)
    idx = findfirst(var -> var[1] == sym, ctx.env_syms)

    !isnothing(idx) ? ctx.env_syms[idx][2] : nothing
end
