using Pkg
Pkg.activate(@__DIR__() * "/../")

using Transpiler
using Transpiler.GLSL
using JuliaGLM

code = @glsl(
    function sdf_disk(
        @out(frag_col::Vec4),
        @uniform(mouse::Vec4),
        @uniform(resolution::IVec2)
    )
        p = (2.0 * gl_FragCoord[:xy] .- resolution["xy"]) ./ resolution["y"]
        m = (2.0 * mouse["xy"] .- resolution["xy"]) ./ resolution["y"]

        d = length(p) - 0.5

        local col
        if d > 0.0
            col = Vec3(0.9, 0.6, 0.3)
        else
            col = Vec3(0.65, 0.85, 1.0)
        end

        col *= 1.0 - exp(-6.0 * abs(d))
        col *= 0.8 + 0.2 * cos(150 * d)
        col = mix(col, Vec3(1), 1.0 - smoothstep(0.0, 0.01, abs(d)))

        if (mouse["z"] > 0.001)
            d = length(m) - 0.5
            col = mix(col, Vec3(1, 1, 0), 1.0 - smoothstep(0.0, 0.005, abs(length(p .- m) - abs(d)) - 0.0025))
            col = mix(col, Vec3(1, 1, 0), 1.0 - smoothstep(0.0, 0.005, length(p .- m) - 0.015))
        end

        frag_col = Vec4(col, 1.0)
    end
)

println(code)
