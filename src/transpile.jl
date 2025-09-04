import .SymbolResolution
import .TypeInference

export @transpile, @glsl

macro transpile(pipeline, f::Expr, verbose=false)
    f = macroexpand(__module__, f, recursive=true)
    def = gensym()
    output = gensym()

    quote
        ($def, $output) = Transpiler.run_pipeline($(esc(pipeline)), $(QuoteNode(f)), $__module__; verbose=$(esc(verbose)))

        $__module__.eval($def)

        if ($verbose)
            println("\nDefined Julia function:")
            println($def)
            println()
        end

        $output
    end
end

function run_pipeline(
    pipeline::Pipeline, f::Expr, mod::Module, pipeline_ctx::Union{PipelineContext,Nothing}=nothing;
    verbose::Bool=false
)::Tuple{Expr,Any,Vector{Tuple{Expr,Any}}}
    Base.remove_linenums!(f)

    if verbose
        println("Running '$(pipeline.name)' pipeline...\n")

        println("Original function definition:")
        println(f)
        println()

        println("Original AST:")
        print_tree(f)
        println()
    end

    if isnothing(pipeline_ctx)
        pipeline_ctx = init_pipeline_ctx(pipeline.ctx_type)
    end

    has_helpers = false
    if length(f.args[2].args) > 0
        first_expr = f.args[2].args[1]
        if first_expr isa Expr && first_expr.head == :function
            has_helpers = true
            transpile_helpers!(pipeline_ctx, pipeline, f, mod; verbose=verbose)
        end
    end

    # Don't print during precompilation
    if ccall(:jl_generating_output, Cint, ()) != 1
        target = get_in_helper(pipeline_ctx) ? "helper function" : "shader"
        println("Transpiling $target...")
    end

    # the data that is passed between stages
    # it is a tuple whose first element is some intermediate tree representation
    # and the rest of the elements can be any satellite data
    stage_data = (f,)

    def = nothing
    def_transform! = get_def_transform(pipeline_ctx)
    for stage in pipeline.stages
        if isnothing(def) && stage isa Stage && !stage.run_before_definition
            def = deepcopy(stage_data[1])

            if has_helpers
                helper_defs = map(h -> h[1], get_helpers(pipeline_ctx))
                prepend!(def.args[2].args, helper_defs)
            end
            def = replace_decls(def)
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

        if get_in_helper(pipeline_ctx) && stage == TypeInference.TypeInferenceStage
            typed_ast = stage_data[1]
            typed_usyms = stage_data[3]
            name = typed_ast.children[1].children[1].original[]
            @assert name isa Symbol

            sig = ()
            for param in typed_ast.children[1].children[2:end]
                param_decl = param.original[]
                param_type = missing

                if param_decl isa Expr && param_decl.head == :decl
                    param_type = param_decl[2]
                elseif param_decl isa Expr && param_decl.head == :(::)
                    param_type = getfield(@__MODULE__, param_decl.args[2])
                    param_type = TypeInference.to_tast(param_type)
                    @assert !isnothing(param_type)
                else
                    error("Invalid parameter declaration found in helper function $name")
                end

                @assert !ismissing(param_type)
                @assert param_type <: TypeInference.ASTType

                sig = (sig..., param_type)
            end

            ret_type = typed_ast.type
            @assert ret_type <: TypeInference.ASTType

            add_helper_ret_type!(pipeline_ctx, name, sig, ret_type)
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
                    print_tree(formatted)
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

    (def, stage_data[1], has_helpers ? get_helpers(pipeline_ctx) : Vector())
end

function transpile_helpers!(ctx::PipelineContext, pipeline::Pipeline, f::Expr, mod::Module; verbose::Bool=false)
    @assert f.head == :function

    set_in_helper!(ctx, true)

    helper_count = 0
    for arg in f.args[2].args
        if !(arg isa Expr && arg.head == :function)
            break
        end

        verbose && println("Transpiling helper function $(arg.args[1].args[1])...")

        (def, output, helpers) = run_pipeline(pipeline, arg, mod, ctx; verbose=verbose)

        @assert isempty(helpers) "Nested helper functions are not allowed"

        add_helper!(ctx, (def, output))
        helper_count += 1

        verbose && println("Finished transpiling helper function $(arg.args[1])")
    end

    deleteat!(f.args[2].args, 1:helper_count)

    set_in_helper!(ctx, false)
end
