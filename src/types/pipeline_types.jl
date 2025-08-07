export Stage, Pipeline

struct Stage
    name::String
    run::Function
    output_formatters::Vector{<:Function}
    output_names::Vector{Union{Nothing,String}}
end

Stage(name::String, run::Function; output_formatters=Vector{Function}(), output_names=Vector{Union{Nothing,String}}()) =
    Stage(name, run, output_formatters, output_names)

Base.string(stage::Stage) = stage.name

struct Pipeline
    name::String
    stages::Vector{<:Union{Stage,Function}}
end

Base.string(pipeline::Pipeline) = pipeline.name
