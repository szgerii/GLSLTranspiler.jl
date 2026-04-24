using GLSLTranspiler
using GLSLTranspiler.GLSL
using JuliaGLM
using StaticArrays

GLSLTranspiler.transpiler_config.gl_rewrite_to_glm = false

@time code = @glsl(
    function test_array(
    )
        @constant global cf_arr = [1.0, 2.0, 3.0, 4.0]
        @constant global ci_us_arr::SVector{Int} = [1, 2, 3]
        @constant global ci_s_arr::SVector{3,Int} = [1, 2, 3]
        arr = [1, 2, 3]
        arr2 = arr
        i = length(arr)
        j = length(cf_arr)
    end,
    #GLSLTranspiler.Verbose
)

println(code)
