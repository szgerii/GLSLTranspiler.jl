using Transpiler
using Transpiler.GLSL
using JuliaGLM

code = @glsl(
    function shadertoy_demo(
        @out(frag_color::Vec4),
        @uniform(time::Float32),
        @uniform(resolution::IVec2)
    )
        uv = gl_FragCoord["xy"] ./ resolution

        col = 0.5f0 .+ 0.5f0 .* cos.(time .+ uv["xyx"] + Vec3(0, 2, 4))

        frag_color = Vec4(col, 1.0f0)
    end
)

println(code)
