using GLSLTranspiler
using GLSLTranspiler.GLSL

shader_fn = :(
    function test()
        a = min(1.0f0, 2.0f0)
    end
)

logging = GLSLTranspiler.Silent

(def, code) = GLSLTranspiler.run_pipeline(
    GLSLTranspiler.GLSL.GLSLPipeline,
    shader_fn,
    @__MODULE__();
    log_level=logging
)

println("Fn def (without import):")
println(def)

println("Gen Code (without import):")
println(code)

import JuliaGLM

(def, code) = GLSLTranspiler.run_pipeline(
    GLSLTranspiler.GLSL.GLSLPipeline,
    shader_fn,
    @__MODULE__();
    log_level=logging
)

println("Fn def (with import):")
println(def)

println("Gen Code (with import):")
println(code)