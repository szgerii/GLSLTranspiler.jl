export Stage, Pipeline

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

export PipelineContext, init_pipeline_ctx

abstract type PipelineContext end

function init_pipeline_ctx(::Type{CtxT})::CtxT where {CtxT<:PipelineContext}
    @assert(
        all(field_type -> missing isa field_type, fieldtypes(CtxT)),
        "Invalid PipelineContext subtype '$CtxT': all fields have to be able to contain the 'missing' value or an explicit init_pipeline_ctx method definition must exist for the context subtype"
    )

    CtxT(fill(missing, fieldcount(CtxT))...)
end

export get_env_syms, get_env_sym_type, get_def_transform

get_env_syms(_::PipelineContext) = Symbol[]

get_env_sym_type(_::Symbol, _::PipelineContext) =
    error("Invalid pipeline context: pipeline uses environment symbols, but does not define a method for get_env_sym_type(sym, ctx)")

get_def_transform(::PipelineContext) = (_, _) -> nothing

export add_helper!, get_helpers, has_helper, get_in_helper, set_in_helper!, get_helper_ret_type, add_helper_ret_type!

add_helper!(::PipelineContext, ::Tuple{Expr,Any}) =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for add_helper!(ctx, helper::Type{Expr,Any})")

get_helpers(::PipelineContext)::Vector{Tuple{Expr,Any}} =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for get_helpers(ctx)")

function has_helper(ctx::PipelineContext, name::Symbol)
    any(f -> f.args[1].args[1] == name, map(h -> h[1], get_helpers(ctx)))
end

get_in_helper(::PipelineContext)::Bool = false
#error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for get_in_helper(ctx)::Bool")
set_in_helper!(::PipelineContext, ::Bool) =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for set_in_helper(ctx, val::Bool)")

get_helper_ret_type(::PipelineContext, ::Symbol, ::Tuple)::Union{DataType,Missing} =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for get_helper_ret_type(ctx, name::Symbol, sig::Tuple)")
add_helper_ret_type!(::PipelineContext, ::Symbol, ::Tuple, ::DataType) =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for add_helper_ret_type(ctx, name::Symbol, sig::Tuple, ret_type::DataType)")

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
