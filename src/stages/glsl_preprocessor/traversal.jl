function glsl_preprocess!(node::Expr, mod::Module)
    for arg in node.args
        glsl_preprocess!(arg, mod)
    end

    # force fn calls that can possibly point to JuliaGLM functions to explicitly refer to those
    if GLSLTranspiler.transpiler_config.rewrite_to_glm && node.head == :call && node.args[1] isa Symbol
        fsym = node.args[1]
        #println(fsym, " outer")

        if isdefined(JuliaGLM, fsym)
            #println(fsym, " inner")
            #node.args[1] = :(JuliaGLM.$(fsym))
        end
    end
end

glsl_preprocess!(_::ASTNode, _::Module) = nothing

precomp_union_types(ASTNode, glsl_preprocess!, (missing, Module))
