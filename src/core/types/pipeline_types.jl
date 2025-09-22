export Stage, Pipeline

"""
    Stage(name, run, output_formatters, output_names, run_before_definition, print_ctx)

Struct for representing pipeline stages.

# Fields
- `name::String`: The name of the stage (used for debugging purposes)
- `run::Function`: The function that will be called by the transpiler with the output of the previous stage, and whose output will be passed on to the next one
- `output_formatters::Vector{<:Function}`: A list of functions used for transforming the output of the stage before it's printed. Each index should be responsible for transforming the output with the matching index. (used for debugging purposes) 
- `output_names::Vector{Union{Nothing,String}}`: A list of names to use instead of the generic auto-numbered ones printed by default. Indexing works similarly to `output_formatters`. Set an index to [`nothing`](@ref) to omit the given output. (used for debugging purposes)
- `run_before_definition::Bool`: Defines whether this stage should run before the transpiler saves the function definition Expr's state for its output. The transpiler will save the output at the first stage it encounters where this is set to false (or after the last stage has run if it hasn't saved yet), so this only works if the pipeline stage also respects this through the stage execution order.
- `print_ctx::Bool`: Whether to print the current pipeline context after the stage has run
"""
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

"""
Abstract type for pipeline contexts, where the pipelines can store data shared between stages.

Concrete subtypes of `PipelineContext` must implement a method for the following functions with their type:
- [`init_pipeline_ctx`](@ref) (unless all fields of the subtype can be initialized to [`missing`](@ref))
- [`get_env_sym`](@ref) (if the pipeline makes use of env symbols. note that the core pipeline does belong here)
- [`get_env_sym_types`](@ref) (if the pipeline makes use of env symbols)

Methods for the following functions must be provided if the pipeline utilizes helper functions:
- [`add_helper!`](@ref)
- [`get_helper`](@ref)
- [`has_helper`](@ref)
- [`get_in_helper`](@ref)
- [`set_in_helper!`](@ref)
- [`get_helper_ret_type`](@ref)
- [`add_helper_ret_type!`](@ref)
- [`add_env_sym!`](@ref)
- [`remove_env_sym!`](@ref)
"""
abstract type PipelineContext end

"""
    init_pipeline_ctx(::Type{CtxT})

Initializes a starting instance of the given [`PipelineContext`](@ref) subtype
"""
function init_pipeline_ctx(::Type{CtxT})::CtxT where {CtxT<:PipelineContext}
    @debug_assert(
        all(field_type -> missing isa field_type, fieldtypes(CtxT)),
        "Invalid PipelineContext subtype '$CtxT': all fields have to be able to contain the 'missing' value or an explicit init_pipeline_ctx method definition must exist for the context subtype"
    )

    CtxT(fill(missing, fieldcount(CtxT))...)
end

export get_env_syms, get_env_sym_type, get_def_transform

"""
    get_env_syms(ctx::PipelineContext) -> Vector{Symbol}

Return the list of env symbols in the context.
"""
get_env_syms(_::PipelineContext) = Symbol[]

"""
    get_env_sym_type(sym::Symbol, ctx::PipelineContext) -> DataType

Return the type for env symbol `sym` in `ctx`.
"""
get_env_sym_type(_::Symbol, _::PipelineContext) =
    error("Invalid pipeline context: pipeline uses environment symbols, but does not define a method for get_env_sym_type(sym, ctx)")

"""
    get_def_transform(ctx::PipelineContext) -> Function

Return the function responsible for performing final transformations on the output function definition before it is saved by the transpiler.
"""
get_def_transform(::PipelineContext) = (_, _) -> nothing

export add_helper!, get_helpers, has_helper, get_in_helper, set_in_helper!, get_helper_ret_type, add_helper_ret_type!

"""
    add_helper!(ctx::PipelineContext, gen::Tuple{Expr, Any})

Register a transpiled helper (whose output by the transpiler was `gen`) into `ctx`. 
"""
add_helper!(::PipelineContext, ::Tuple{Expr,Any}) =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for add_helper!(ctx, helper::Type{Expr,Any})")

"""
    get_helpers(ctx::PipelineContext) -> Vector{Tuple{Expr, Any}}

Return the list of transpiled helpers registered into `ctx`
"""
get_helpers(::PipelineContext)::Vector{Tuple{Expr,Any}} =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for get_helpers(ctx)")

"""
    has_helper(ctx::PipelineContext, name::Symbol) -> Bool

Return whether a transpiled helper named `name` exists in `ctx`.
"""
function has_helper(ctx::PipelineContext, name::Symbol)
    any(f -> f.args[1].args[1] == name, map(h -> h[1], get_helpers(ctx)))
end

"""
    get_in_helper(ctx::PipelineContext) -> Bool

Return whether the pipeline beloning to `ctx` is being used to transpile a helper right now.
"""
get_in_helper(::PipelineContext)::Bool = false

"""
    set_in_helper!(ctx::PipelineContext, val::Bool)

Set whether the pipeline belonging to `ctx` is being used to transpile a helper right now.
"""
set_in_helper!(::PipelineContext, ::Bool) =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for set_in_helper(ctx, val::Bool)")

"""
    get_helper_ret_type(ctx::PipelineContext, name::Symbol, sig::Tuple) -> Union{DataType, Missing}

Return the return type of helper named `name` in `ctx` with type signature `sig`, or [`missing`](@ref) if it can't be found.
"""
get_helper_ret_type(::PipelineContext, ::Symbol, ::Tuple)::Union{DataType,Missing} =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for get_helper_ret_type(ctx, name::Symbol, sig::Tuple)")
"""
    add_helper_ret_type!(ctx::PipelineContext, name::Symbol, sig::Tuple, ret_type::DataType)

Register a helper named `name` into `ctx` with type signature `sig` and return type `ret_type`.
"""
add_helper_ret_type!(::PipelineContext, ::Symbol, ::Tuple, ::DataType) =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for add_helper_ret_type!(ctx, name::Symbol, sig::Tuple, ret_type::DataType)")

export add_env_sym!, remove_env_sym!

"""
    add_env_sym!(ctx::PipelineContext, name::Symbol, type::DataType)

Registers an env symbol named `name` with type `type` into `ctx`.
"""
add_env_sym!(::PipelineContext, ::Symbol, ::DataType) =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for add_env_sym!(ctx, name::Symbol, type::DataType)")
"""
    remove_env_sym!(ctx::PipelineContext, name::Symbol)

Removes the env symbol named `name` from `ctx`.
"""
remove_env_sym!(::PipelineContext, ::Symbol) =
    error("Invalid pipeline context: pipeline uses helper functions, but doesn't define a method for remove_env_sym!(ctx, name::Symbol)")

"""
    Pipeline(name, stages, ctx_type)

Struct for representing transpiler pipelines.

# Fields:
- `name::String`: The name of the pipeline (used for debugging purposes)
- `stages::Vector{<:Union{Stage,Function}}`: The stages that make up this pipeline, in execution order. Note that instead of using the [`Stage`](@ref) type, [`Function`](@ref)s can be provided as well, which should act exactly like the `run` field of `Stage` (as long as you don't need stage-level debugging features or definition delaying).
- `ctx_type::DataType`: The pipeline context type used by the pipeline. This must be a type whose supertype is [`PipelineContext`](@ref)
"""
struct Pipeline
    name::String
    stages::Vector{<:Union{Stage,Function}}
    ctx_type::DataType

    function Pipeline(
        name::String, stages::Vector{<:Union{Stage,Function}}, ::Type{CtxT}
    ) where {CtxT<:PipelineContext}
        @debug_assert isconcretetype(CtxT) "Cannot define pipeline '$name' with non-concrete context type $CtxT"

        new(name, stages, CtxT)
    end
end

Base.string(pipeline::Pipeline) = pipeline.name
