function glsl_preprocess(node::Expr, mod::Module, ctx::PipelineContext, decl_type::Union{Symbol,Nothing}=nothing)
    arg_decls = node.head in [:global, :local] ? node.head : decl_type

    for (i, arg) in enumerate(node.args)
        node.args[i] = glsl_preprocess(arg, mod, ctx, arg_decls)
    end

    # force fn calls that can possibly point to JuliaGLM functions to explicitly refer to those
    if Transpiler.transpiler_config.rewrite_to_glm && node.head == :call && node.args[1] isa Symbol
        fsym = node.args[1]
        #println(fsym, " outer")

        if isdefined(JuliaGLM, fsym)
            #println(fsym, " inner")
            #node.args[1] = :(JuliaGLM.$(fsym))
        end
    elseif node.head == Symbol("'")
        @assert length(node.args) == 1

        return :(transpose($(node.args[1])))
    elseif node.head == :decl
        node.args[3] = decl_type
        if any(qualifier -> qualifier isa Union{InQualifier,OutQualifier,UniformQualifier}, node.args[4])
            push!(ctx.env_syms, (node.args[1].value, node.args[2]))
        end
    end

    node
end

glsl_preprocess(node, _::Module, ctx::PipelineContext, decl_type) = node

precomp_union_types(ASTNode, glsl_preprocess, (missing, Module))
