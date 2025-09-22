using Pkg
Pkg.activate(@__DIR__() * "/../")

using Transpiler
using Transpiler.GLSL

shader_fn = :(
    function test()
        a = min(1.0f0, 2.0f0)
    end
)

logging = Transpiler.Silent

(def, code) = Transpiler.run_pipeline(
    Transpiler.GLSL.GLSLPipeline,
    shader_fn,
    @__MODULE__();
    log_level=logging
)

println("Fn def (without import):")
println(def)

println("Gen Code (without import):")
println(code)

import JuliaGLM

(def, code) = Transpiler.run_pipeline(
    Transpiler.GLSL.GLSLPipeline,
    shader_fn,
    @__MODULE__();
    log_level=logging
)

println("Fn def (with import):")
println(def)

println("Gen Code (with import):")
println(code)