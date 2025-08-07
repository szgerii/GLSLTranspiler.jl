using Logging

export @transpile, @glsl

macro transpile(pipeline, f::Expr)
    # save the original function definition AST so that it can be modified by the transpiler
    # without it having an effect on the Julia function itself
    original_f = deepcopy(f)

    quote
        with_logger(PipelineLogger(Logging.Debug)) do
            GLSLTranspiler.run_pipeline($(esc(pipeline)), $(QuoteNode(f)), $__module__)
        end

        $(esc(original_f))
    end
end

macro glsl(f::Expr)
    original_f = deepcopy(f)

    quote
        with_logger(PipelineLogger(Logging.Debug)) do
            GLSLTranspiler.run_pipeline(glsl_pipeline, $(QuoteNode(f)), $__module__)
        end

        $(esc(original_f))
    end
end

function run_pipeline(pipeline::Pipeline, f::Expr, mod::Module)
    println("Running '$(pipeline.name)' pipeline...\n")

    Base.remove_linenums!(f)

    println("Original function definition:")
    println(f)
    println()

    println("Original AST:")
    print_traverse(f)
    println()

    # the data that is passed between stages
    # it is a tuple whose first element is some intermediate tree representation
    # and the rest of the elements can be any satellite data
    stage_data = (f,)

    for stage in pipeline.stages
        stage_name = string(stage)

        if stage isa Function
            remove_prefix = "run_"

            if startswith(stage_name, remove_prefix)
                stage_name = stage_name[length(remove_prefix)+1:end]
            end
        end

        stage_fn = stage isa Stage ? stage.run : stage

        println("Running '$stage_name' stage...")
        stage_data = stage_fn(mod, stage_data...)

        if !(stage_data isa Tuple)
            stage_data = (stage_data,)
        end

        println("\nFinished '$stage_name' stage, output:")
        for (i, output) in enumerate(stage_data)
            has_custom_formatter = stage isa Stage && length(stage.output_formatters) >= i
            formatter = has_custom_formatter ? stage.output_formatters[i] : identity
            formatted = formatter(output)

            has_custom_name = stage isa Stage && length(stage.output_names) >= i && !isnothing(stage.output_names[i])
            name = has_custom_name ? stage.output_names[i] : "Output #$i"

            println("\n<$name>:")
            if output isa AbstractTree
                print_traverse(formatted)
            elseif !isnothing(formatted)
                println(formatted)
            end
        end
        println()
    end

    println("Finished pipeline '$(pipeline.name)'")
end
