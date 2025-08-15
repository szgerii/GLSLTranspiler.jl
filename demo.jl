using Pkg
Pkg.activate(@__DIR__)

# include("lib/GLM/glm.jl")
# include("src/GLSLTranspiler.jl")

using GLSLTranspiler
using GLSLTranspiler.GLSL

some_global = 2
some_other_global = 3

@skip @transpile GLSLTranspiler.GLSL.glsl_pipeline function test_fn(a::Int, b::Int)
    # global 1
    some_global = 2
    # local 1.1 because of assignment
    some_other_global = 10

    # global 1
    global some_global
    some_global

    # local 1.1
    acc = 0
    j = 3

    # local 1.1
    while acc <= 5
        # local 1.1.1
        i = 1

        # 1.1 += 1.1.1 + 1.1
        # technically 1.1 = 1.1 + 1.1.1 + 1.1 after the preprocessor stage
        acc += i + b
        # local 1.1
        j = 4

        # local 1.1 && 1.1.1
        while j > 3 && i != 10 && false
            # local 1.1.1.1
            local j, acc
            j = 2
            acc = 3

            # local 1.1.1
            i = 10
        end

        # local 1.1.1
        while i < 5 && false
            # local 1.1.1.2
            i = 3
            local i
        end

        # local 1.1
        # j == 4 here
        j
    end

    # local 1.1
    acc
end

i = 0
j = 1

const Vec2 = GLSLTranspiler.Vec2
const Vec3 = GLSLTranspiler.Vec3
const Vec4 = GLSLTranspiler.Vec4
const IVec2 = GLSLTranspiler.Vec2T{Int32}
const IntVec3 = GLSLTranspiler.Vec3T{Int32}

@skip @transpile(
    GLSLTranspiler.GLSL.glsl_pipeline,
    function preprocessor()
        global i, j
        i += 2
        i = i + 2
        0 < j < i

        v3 = Vec3(1, 2, 3)
        cos.(v3)
    end
)

@skip @transpile(
    GLSLTranspiler.GLSL.glsl_pipeline,
    function scope()
        i = 1

        while i < 10
            i += 1

            j = 1
            while j < 5
                j += 1
            end

            k = 1
            while k < 5
                k += 1

                h = 1
                while h < 5
                    h += 1
                end
            end

            g = 1
            while g < 5
                g += 1
            end
        end
    end
)

@skip @transpile(
    GLSLTranspiler.GLSL.glsl_pipeline,
    function symbols()
        i = 1
        j = 3

        while i < 5
            k = 3

            local j
            j = 2
        end
    end
)

@skip @transpile(
    GLSLTranspiler.GLSL.glsl_pipeline,
    function glsl_preprocessor(
        @in(normal::Vec3),
        @out(frag_col::Vec4),
        @uniform(Ls::Vec3),
        @uniform(shininess::Float32)
    )
        frag_col = Vec4(normal, 1.0)
    end
)

@skip @transpile(
    GLSLTranspiler.GLSL.glsl_pipeline,
    function green(@out(out_col::Vec4))
        out_col = Vec4(0, 1, 0, 1)
    end
)

@skip @transpile(
    GLSLTranspiler.GLSL.glsl_pipeline,
    function shadertoy_demo(
        @out(frag_color::Vec4),
        @uniform(time::Float32),
        @uniform(resolution::IVec2)
    )
        uv = gl_FragCoord["xy"] ./ resolution

        col = 0.5f0 .+ 0.5f0 .* cos.(time .+ uv["xyx"] + Vec3(0, 2, 4))

        frag_color = Vec4(col, 1.0f0)
    end,
    true
)

@skip @transpile(
    GLSLTranspiler.GLSL.glsl_pipeline,
    function mouse_follow(
        @out(color::Vec4),
        @uniform(time::Float32),
        @uniform(mouse::Vec2),
        @uniform(resolution::IVec2)
    )
        frag_pos = gl_FragCoord["xy"]
        frag_pos["y"] = -frag_pos["y"] + resolution["y"]

        dist = distance(frag_pos, mouse)
        if dist < 50.0f0
            f_in = time * 2.0f0
            color = Vec4(0.5f0 * (1 + sin(f_in)), 0.2f0, 0.5f0 * (1 + cos(f_in + 3.1415f0 / 2.0f0)), 1.0f0)
        else
            discard()
        end
    end,
    true
)

@transpile(
    GLSLTranspiler.GLSL.glsl_pipeline,
    function sdf_disk(
        @out(frag_col::Vec4),
        @uniform(mouse::Vec4),
        @uniform(resolution::IVec2)
    )
        p = (2.0f0 .* gl_FragCoord["xy"] .- resolution["xy"]) ./ resolution["y"]
        m = (2.0f0 .* mouse["xy"] .- resolution["xy"]) ./ resolution["y"]

        d = length(p) - 0.5f0

        local col
        if d > 0.0f0
            col = Vec3(0.9f0, 0.6f0, 0.3f0)
        else
            col = Vec3(0.65f0, 0.85f0, 1.0f0)
        end

        col *= 1.0f0 - exp(-6.0f0 * abs(d))
        col *= 0.8f0 + 0.2f0 * cos(150f0 * d)
        col = mix(col, Vec3(1), 1.0f0 - smoothstep(0.0f0, 0.01f0, abs(d)))

        if (mouse["z"] > 0.001f0)
            d = length(m) - 0.5f0
            col = mix(col, Vec3(1, 1, 0), 1.0f0 - smoothstep(0.0f0, 0.005f0, abs(length(p .- m) - abs(d)) - 0.0025f0))
            col = mix(col, Vec3(1, 1, 0), 1.0f0 - smoothstep(0.0f0, 0.005f0, length(p .- m) - 0.015f0))
        end
    end,
    true
)
