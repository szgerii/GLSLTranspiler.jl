export @transpile, @glsl

macro transpile(pipeline, f::Expr, verbose=false)
    f = macroexpand(__module__, f, recursive=true)
    def = gensym()
    output = gensym()

    quote
        ($def, $output) = GLSLTranspiler.run_pipeline($(esc(pipeline)), $(QuoteNode(f)), $__module__; verbose=$(esc(verbose)))

        $__module__.eval($def)

        $output
    end
end

function run_pipeline(pipeline::Pipeline, f::Expr, mod::Module; verbose::Bool=false)::Tuple{Expr,Any}
    Base.remove_linenums!(f)

    if verbose
        println("Running '$(pipeline.name)' pipeline...\n")

        println("Original function definition:")
        println(f)
        println()

        println("Original AST:")
        print_traverse(f)
        println()
    end

    # the data that is passed between stages
    # it is a tuple whose first element is some intermediate tree representation
    # and the rest of the elements can be any satellite data
    stage_data = (f,)

    pipeline_ctx = init_pipeline_ctx(pipeline.ctx_type)
    def = nothing
    def_transform! = get_def_transform(pipeline_ctx)
    for stage in pipeline.stages
        if isnothing(def) && stage isa Stage && !stage.run_before_definition
            def = deepcopy(stage_data[1])
            def_transform!(def, pipeline_ctx)
        end

        stage_name = string(stage)

        if stage isa Function
            remove_prefix = "run_"

            if startswith(stage_name, remove_prefix)
                stage_name = stage_name[length(remove_prefix)+1:end]
            end
        end

        stage_fn = stage isa Stage ? stage.run : stage
        print_ctx = stage isa Stage && stage.print_ctx

        verbose && println("Running '$stage_name' stage...")
        stage_data = stage_fn(mod, pipeline_ctx, stage_data...)

        if !(stage_data isa Tuple)
            stage_data = (stage_data,)
        end

        verbose && println("\nFinished '$stage_name' stage, output:")
        for (i, output) in enumerate(stage_data)
            has_custom_formatter = stage isa Stage && length(stage.output_formatters) >= i
            formatter = has_custom_formatter ? stage.output_formatters[i] : identity
            formatted = formatter(output)

            if isnothing(formatted)
                formatted = "[...] (omitted)"
            end

            has_custom_name = stage isa Stage && length(stage.output_names) >= i && !isnothing(stage.output_names[i])
            name = has_custom_name ? stage.output_names[i] : "Output #$i"

            if verbose
                println("\n<$name>:")
                if output isa AbstractTree
                    print_traverse(formatted)
                elseif !isnothing(formatted)
                    println(formatted)
                end
            end
        end
        verbose && println()

        if verbose && print_ctx
            println("<Pipeline Context>:\n")
            for field_name in fieldnames(typeof(pipeline_ctx))
                println("[$field_name]:")
                println(string(getfield(pipeline_ctx, field_name)))
            end
            println()
        end
    end

    if isnothing(def)
        def = deepcopy(stage_data[1])
        def_transform!(def, pipeline_ctx)
    end

    verbose && println("Finished pipeline '$(pipeline.name)'\n")

    (def, stage_data[1])
end
