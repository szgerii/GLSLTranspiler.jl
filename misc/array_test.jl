using Transpiler
using Transpiler.GLSL
using JuliaGLM
using StaticArrays

Transpiler.transpiler_config.gl_rewrite_to_glm = false

code = @glsl(
    function test_array(
        @uniform(arr::SVector{10,Float32}),
        @uniform(arr2::SVector{Float32})
    )
    end,
    #Transpiler.Verbose
)

println(code)
