function glsl_preprocess(node::Expr, mod::Module, ctx::PipelineContext, decl_type::Union{Symbol,Nothing}=nothing)
    arg_decls = node.head in [:global, :local] ? node.head : decl_type

    for (i, arg) in enumerate(node.args)
        node.args[i] = glsl_preprocess(arg, mod, ctx, arg_decls)
    end

    if Transpiler.transpiler_config.rewrite_to_glm && node.head == :call && node.args[1] isa Symbol
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
        @assert length(node.args) == 1

        return :(transpose($(node.args[1])))
    elseif node.head == :decl
        # add in/out/uniform qualified variable decls to the env sym list
        node.args[3] = decl_type
        if any(qualifier -> qualifier isa Union{InQualifier,OutQualifier,UniformQualifier}, node.args[4])
            push!(ctx.env_syms, (node.args[1].value, node.args[2]))
        end
    end

    node
end

glsl_preprocess(node, _::Module, ctx::PipelineContext, decl_type) = node

precomp_union_types(ASTNode, glsl_preprocess, (missing, Module))
