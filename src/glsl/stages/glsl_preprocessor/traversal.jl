const ConstantType = Union{Int32,Int64,Float32,Float64,UInt32,Bool,JuliaGLM.VecNT,JuliaGLM.MatTNxM}

function glsl_preprocess(node::Expr, mod::Module, ctx::PipelineContext, decl_type::Union{Symbol,Nothing}=nothing)
    # print "pretty" error message for out of order declarations
    # e.g. local @constant x::Int instead of @constant local x::Int
    arg_1 = get(node.args, 1, nothing)
    if node.head in [:global, :local] && arg_1 isa Expr && arg_1.head == :decl
        ast_error(node,
            "Invalid declaration encountered during transpilation!\n",
            "This might be because qualifiers have been used out of order (global @constant v::Vec3 instead of @constant global v::Vec3). ",
            "Make sure qualifier macros precede the local/global keywords."
        )
    end
    
    arg_decls = node.head in [:global, :local] ? node.head : decl_type

    if node.head == :decl && !ismissing(node.args[3])
        arg_decls = node.args[3]
    end

    for (i, arg) in enumerate(node.args)
        node.args[i] = glsl_preprocess(arg, mod, ctx, arg_decls)
    end

    if Transpiler.transpiler_config.gl_rewrite_to_glm && node.head == :call && node.args[1] isa Symbol
        # force fn calls that can point to JuliaGLM functions to explicitly refer to those
        fsym = node.args[1]

        if isdefined(JuliaGLM, fsym)
            # retrieve the function object
            f = getfield(JuliaGLM, fsym)

            # only apply this rule if the function is defined in JuliaGLM
            # this filters out functions coming from Base, Core, etc. (e.g. :+)
            if parentmodule(f) == JuliaGLM
                node.args[1] = :(JuliaGLM.$fsym)
            end
        end
    elseif node.head == Symbol("'")
        # rewrite mat' syntax to transpose(mat)
        @debug_assert length(node.args) == 1

        return :(transpose($(node.args[1])))
    elseif node.head == :decl
        is_const = any(qual -> qual isa ConstantQualifier, node.args[4])

        if ismissing(node.args[3])
            node.args[3] = is_const ? :global : decl_type
        end

        scope = node.args[3] isa QuoteNode ? node.args[3].value : node.args[3]

        if is_const
            if scope != :global
                ast_error(node, "Trying to declare const in non-global context")
            end
            
            if isnothing(node.args[5])
                ast_error(node, "Trying to declare const without an initial value")
            end

            const_val_candidate = missing

            if node.args[5] isa ConstantType
                # fast track literals
                const_val_candidate = node.args[5]
            elseif node.args[5] isa ASTNode
                if Transpiler.transpiler_config.gl_const_eval
                    expr = node.args[5] isa QuoteNode ? node.args[5].value : node.args[5]
                    # try to get a transpile-time known value for the constant
                    # by evaluating it in the calling module
                    try
                        const_val_candidate = mod.eval(expr)
                    catch ex
                        if haskey(ENV, "TRANSPILER_DEBUG")
                            println("Exception caught during transpile-evaluation for $(node.args[1]):")
                            println(ex)
                            println("The above error was printed because TRANSPILER_DEBUG is enabled")
                        end
                    end
                else
                    println("WARNING: Found complex expression on const assignment right-hand side, which was not transpile-time evaluated, as the gl_const_eval config option is turned off.")
                end
            else
                ast_error(
                    node,
                    "Invalid value type for @constant initial value: ", typeof(node.args[5]), "\n",
                    "Received value was: ", node.args[5]
                )
            end

            f32_rewrite = 
                    Transpiler.transpiler_config.literals_as_f32 &&
                    const_val_candidate isa Float64
            
            if f32_rewrite
                const_val_candidate = convert(Float32, const_val_candidate)
            end

            if ismissing(const_val_candidate)
                ast_error(
                    node,
                    "Failed to get value from @constant initial value expression: $(node.args[1]) = $(node.args[5])\n",
                    "This could be because the expression isn't a transpile-time constant, or it resolves to an invalid variable type."
                )
            elseif !ismissing(node.args[2])
                i32_rewrite =
                    const_val_candidate isa Union{Int32,Int64} &&
                    node.args[2] <: Union{Int32,Int64} &&
                    typeof(const_val_candidate) != node.args[2]

                if i32_rewrite
                    node.args[2] = Int32
                    const_val_candidate = convert(Int32, const_val_candidate)
                elseif !(const_val_candidate isa node.args[2])
                    ast_error(
                        node,
                        "Type of @constant initial value does not match the declared type ",
                        "in a declaration for ", node.args[1], "\n",
                        "$const_val_candidate is a $(typeof(const_val_candidate)), not a $(node.args[2])",
                    )
                end
            else
                node.args[2] = typeof(const_val_candidate)
            end
            
            node.args[5] = const_val_candidate
        end

        #if any(qualifier -> qualifier isa Union{InQualifier,OutQualifier,UniformQualifier,ConstantQualifier}, node.args[4])        
        final_scope = node.args[3] isa QuoteNode ? node.args[3].value : node.args[3]
        @debug_assert final_scope isa Symbol

        if final_scope == :global
            glsl_type = to_glsl_type(node.args[2])
            init_val = nothing

            if !isnothing(node.args[5]) && node.args[5] isa node.args[2]
                init_val = GLSLLiteral(node.args[5], glsl_type)
            end

            glsl_decl = GLSLDeclaration(GLSLSymbol(node.args[1].value), glsl_type, node.args[4], init_val)

            push!(ctx.interface_decls, glsl_decl)
            # push!(ctx.env_syms, (glsl_decl.symbol.sym, node.args[2]))

            return Expr(:block)
        end
    end

    node
end

glsl_preprocess(node, _::Module, ctx::PipelineContext, decl_type) = node

precomp_union_types(ASTNode, glsl_preprocess, (missing, Module))
