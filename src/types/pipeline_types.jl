export Stage, Pipeline, PipelineContext, init_pipeline_ctx, get_env_syms, get_env_sym_type, env_fn_ret, get_def_transform

struct Stage
    name::String
    run::Function
    output_formatters::Vector{<:Function}
    output_names::Vector{Union{Nothing,String}}
    run_before_definition::Bool
    print_ctx::Bool
end

Stage(
    name::String, run::Function;
    output_formatters=Vector{Function}(),
    output_names=Vector{Union{Nothing,String}}(),
    run_before_definition::Bool=false,
    print_ctx::Bool=false
) = Stage(name, run, output_formatters, output_names, run_before_definition, print_ctx)

Base.string(stage::Stage) = stage.name

abstract type PipelineContext end

function init_pipeline_ctx(::Type{CtxT})::CtxT where {CtxT<:PipelineContext}
    @assert(
        all(field_type -> missing isa field_type, fieldtypes(CtxT)),
        "Invalid PipelineContext subtype '$CtxT': all fields have to be able to contain the 'missing' value or an explicit init_pipeline_ctx method definition must exist for the context subtype"
    )

    CtxT(fill(missing, fieldcount(CtxT))...)
end

get_env_syms(_::PipelineContext) = Symbol[]
get_env_sym_type(_::Symbol, _::PipelineContext) =
    error("Invalid pipeline context: pipeline uses environment symbols, but does not define method for get_env_sym_type(sym, ctx)")

env_fn_ret(::Type{<:PipelineContext}, fsym::Val, arg_types...) = missing
env_fn_ret(ctx::T, fsym::Val, arg_types...) where {T<:PipelineContext} = env_fn_ret(T, fsym, arg_types...)

get_def_transform(_::PipelineContext) = (_, _) -> nothing

struct Pipeline
    name::String
    stages::Vector{<:Union{Stage,Function}}
    ctx_type::DataType

    function Pipeline(
        name::String, stages::Vector{<:Union{Stage,Function}}, ::Type{CtxT}
    ) where {CtxT<:PipelineContext}
        @assert isconcretetype(CtxT) "Cannot define pipeline '$name' with non-concrete context type $CtxT"

        new(name, stages, CtxT)
    end
end

Base.string(pipeline::Pipeline) = pipeline.name
