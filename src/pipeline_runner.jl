import .SymbolResolution
import .TypeInference

export @transpile, run_pipeline

"""
Logging levels that can be used to control the amount of transpilation progress reporting.

# Values
- `Silent`: The transpiler prints nothing to stdout
- `Progress`: The transpiler prints information about beginning and finishing the pipeline (separately for each helper function) to stdout
- `Verbose`: The transpiler prints detailed information about the output of every stage, as well as progress reporting info to stdout
"""
@enum TranspilerLogLevel Silent Progress Verbose

"""
    @transpile(pipeline, f::Expr, log_level::TranspilerLogLevel = Silent)

Shorthand for calling [`run_pipeline`](@ref), if you want to automatically define the input function as well as the helper functions into the calling module.

The code block inserted by this macro will call [`run_pipeline`](@ref) with `pipeline` on the function definition [`Expr`](@ref) `f`, setting the logging level to `log_level`.
In the end, it will return the generated code String.

# Examples
```jldoctest
julia> code = @transpile(
           Transpiler.GLSL.glsl_pipeline,
           function my_shader_fn(#= ... =#)
               #= ... =#
           end
       )

julia> code isa String
true
```
"""
macro transpile(pipeline, f::Expr, log_level=Silent)
    def = gensym()
    output = gensym()
    helpers = gensym()

    quote
        ($def, $output, $helpers) = Transpiler.run_pipeline($(esc(pipeline)), $(QuoteNode(f)), $__module__; log_level=$(esc(log_level)))

        $__module__.eval($def)

        #for helper in $helpers
        #    $__module__.eval(helper[1])
        #end

        if ($(esc(log_level)) == $Progress)
            println("\nDefined Julia function:")
            println($def)
            println()
        end

        $output
    end
end

"""
    run_pipeline(pipeline::Pipeline, f::Expr, mod::Module,
        pipeline_ctx::Union{PipelineContext,Nothing} = nothing;
        log_level::TranspilerLogLevel = Silent
    ) -> Tuple{Expr, Any, Vector{Tuple{Expr,Any}}}

Transpile the function definition expression `f` according to `pipeline` and return its valid Julia definition, the generated code and a list of the previous two for each helper function.

`pipeline_ctx` is mainly used internally for sharing context between helper functions. So unless you want to explicitly share a pipeline context between different transpilations, leave it at its default [`nothing`](@ref) value.

# Arguments

- `pipeline::Pipeline`: The [`Pipeline`](@ref) object responsible for defining the sequence of stages the transpiler will apply to the input. It's also used for creating the pipeline context.
- `f::Expr`: The input function definition to transpile
- `mod::Module`: The module to use as transpilation context. This is used for looking up global symbols and such.
- `pipeline_ctx::Union{PipelineContext, Nothing}`: If set to [`nothing`](@ref), the transpiler will create a new, empty pipeline context based on `pipeline`. Otherwise, it will use the provided `pipeline_ctx` as a staring point. Defaults to `nothing`. (Used internally for helper functions, do not modify the default value, unless you know what you're doing.)
- `log_level::TranspilerLogLevel`: Controls the amount of intermediate debugging data printed to stdout. See [`TranspilerLogLevel`](@ref) for possible values. Defaults to `Silent`.

# Returns

The transpiler returns a Tuple made up of the following three things (in return order):
- `Expr`: The Julia function definition that can be defined in the module. This is stripped from decorators, qualifiers, etc. and some minimal transformations might have been applied to it. It should be functionally identical to the original definition, but each pipeline can decide what exactly it marks as a ready Julia definition.
- `Any`: This is the real output of the transpiler. Usually it should be a String, containing the generated code, but pipelines can choose to return whatever they want here.
- `Vector{Tuple{Expr, Any}}`: A list of the previous two parameters, repeated for each helper function in the base fn definition. The second parameter should contain the generated helper code already, this is mainly useful if you want to define the helper functions in Julia as well, or if you want to do some extra work with their generated code.
"""
function run_pipeline(
    pipeline::Pipeline, f::Expr, mod::Module, pipeline_ctx::Union{PipelineContext,Nothing}=nothing;
    log_level::TranspilerLogLevel=Silent
)::Tuple{Expr,Any,Vector{Tuple{Expr,Any}}}
    f = macroexpand(mod, f; recursive=true)

    Base.remove_linenums!(f)

    if log_level == Verbose
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
            transpile_helpers!(pipeline_ctx, pipeline, f, mod; log_level=log_level)
        end
    end

    # Don't print during precompilation
    if log_level != Silent && ccall(:jl_generating_output, Cint, ()) != 1
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

        log_level == Verbose && println("Running '$stage_name' stage...")
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

        log_level == Verbose && println("\nFinished '$stage_name' stage, output:")
        for (i, output) in enumerate(stage_data)
            has_custom_formatter = stage isa Stage && length(stage.output_formatters) >= i
            formatter = has_custom_formatter ? stage.output_formatters[i] : identity
            formatted = formatter(output)

            if isnothing(formatted)
                formatted = "[...] (omitted)"
            end

            has_custom_name = stage isa Stage && length(stage.output_names) >= i && !isnothing(stage.output_names[i])
            name = has_custom_name ? stage.output_names[i] : "Output #$i"

            if log_level == Verbose
                println("\n<$name>:")
                if output isa AbstractTree
                    print_tree(formatted)
                elseif !isnothing(formatted)
                    println(formatted)
                end
            end
        end
        log_level == Verbose && println()

        if log_level == Verbose && print_ctx
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

    log_level == Verbose && println("Finished pipeline '$(pipeline.name)'\n")

    (def, stage_data[1], has_helpers ? get_helpers(pipeline_ctx) : Vector())
end

function transpile_helpers!(ctx::PipelineContext, pipeline::Pipeline, f::Expr, mod::Module; log_level::TranspilerLogLevel=Silent)
    @assert f.head == :function

    set_in_helper!(ctx, true)

    param_env_syms = []
    for param in get_param_names(f)
        decl = get_param(f, param)

        @assert !(decl isa Symbol)
        if decl.head == :decl
            push!(param_env_syms, (param, TypeInference.to_ast(decl.args[2])))
        elseif decl.head == :(::)
            push!(param_env_syms, (param, decl.args[2]))
        else
            ast_error(decl, "Invalid function parameter declaration")
        end
    end

    helper_count = 0
    for arg in f.args[2].args
        if !(arg isa Expr && arg.head == :function)
            break
        end

        log_level != Silent && println("Transpiling helper function $(arg.args[1].args[1])...")

        for pes in param_env_syms
            add_env_sym!(ctx, pes...)
        end

        (def, output, helpers) = run_pipeline(pipeline, arg, mod, ctx; log_level=log_level)

        @assert isempty(helpers) "Nested helper functions are not allowed"

        for pes in param_env_syms
            remove_env_sym!(ctx, pes[1])
        end

        add_helper!(ctx, (def, output))
        helper_count += 1

        log_level == Verbose && println("Finished transpiling helper function $(arg.args[1])")
    end

    deleteat!(f.args[2].args, 1:helper_count)

    set_in_helper!(ctx, false)
end
