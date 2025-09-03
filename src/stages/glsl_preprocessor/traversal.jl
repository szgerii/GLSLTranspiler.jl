function glsl_preprocess(node::Expr, mod::Module)
    for (i, arg) in enumerate(node.args)
        node.args[i] = glsl_preprocess(arg, mod)
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
    end

    node
end

glsl_preprocess(node::ASTNode, _::Module) = node

precomp_union_types(ASTNode, glsl_preprocess, (missing, Module))
