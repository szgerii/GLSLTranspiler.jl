using Pkg
Pkg.activate(@__DIR__() * "/../")

using Transpiler
using Transpiler.GLSL
using JuliaGLM

code = @glsl(
    function rounded_box(
        @out(frag_col::Vec4),
        @uniform(resolution::IVec2),
        @uniform(mouse::Vec4),
        @uniform(time::Float32)
    )
        function sd_round_box(p::Vec2, b::Vec2, r::Vec4)
            if p["x"] <= 0.0
                r["xy"] = r["zw"]
            end

            if p["y"] <= 0.0
                r["x"] = r["y"]
            end

            q = abs(p) - b .+ r["x"]

            min(max(q["x"], q["y"]), 0.0) + length(max(q, 0.0)) - r["x"]
        end

        p = (2.0 * gl_FragCoord["xy"] - resolution["xy"]) ./ resolution["y"]
        m = (2.0 * mouse["xy"] - resolution["xy"]) ./ resolution["y"]

        si = vec2(0.9, 0.6) + 0.3 * cos(time .+ vec2(0, 2))
        ra = 0.3 .+ 0.3 * cos(2.0 * time .+ vec4(0, 1, 2, 3))
        ra = min(ra, min(si["x"], si["y"]))

        d = sd_round_box(p, si, ra)

        local col
        if d > 0.0
            col = vec3(0.9, 0.6, 0.3)
        else
            col = vec3(0.65, 0.85, 1.0)
        end
        col *= 1.0 - exp2(-20.0 * abs(d))
        col *= 0.8 + 0.2 * cos(120.0 * d)
        col = mix(col, vec3(1), 1.0 - smoothstep(0.0, 0.01, abs(d)))

        if mouse["z"] > 0.001
            d = sd_round_box(m, si, ra)
            col = mix(col, vec3(1, 1, 0), 1.0 - smoothstep(0.0, 0.005, abs(length(p - m) - abs(d)) - 0.0025))
            col = mix(col, vec3(1, 1, 0), 1.0 - smoothstep(0.0, 0.005, length(p - m) - 0.015))
        end

        frag_col = vec4(col, 1)
    end
)

println(code)
