using Pkg
Pkg.activate(@__DIR__)

# include("lib/GLM/glm.jl")
# include("src/GLSLTranspiler.jl")

using GLSLTranspiler
using GLSLTranspiler.GLSL

some_global = 2
some_other_global = 3

#@transpile GLSLTranspiler.glsl_pipeline function test_fn(a, b::Float64)
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
    function test_fn(@in(a::Int), @out(b::Float32), @uniform(c::IntVec3))
        v2, v3 = Vec2(1.0f0, 2.0f0), Vec3(1.0f0, 2.0f0, 3.0f0)
        iv3 = IntVec3(a, 2, 3)
        v4 = Vec4(1.0f0, 2.0f0, 3.0f0, 4.0f0)

        v2 = cos.(v2)

        i = 1

        global i

        if i < 3
            i += 1
        elseif i < 4
            i += 2
        elseif i < 5
            i += 3
        else
            i += 10
        end

        j = 1

        while i < 20
            sub = 2.0f0
            sub2 = 2.0

            while i < 10
                global i
                i += 1
            end

            global i

            i += 1
            i *= 2
        end
    end
)

@skip @transpile(
    GLSLTranspiler.GLSL.glsl_pipeline,
    function green(@out(out_col::Vec4))
        out_col = Vec4(0, 1, 0, 1)
    end
)

@skip code = @transpile(
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

@transpile(
    GLSLTranspiler.GLSL.glsl_pipeline,
    function mouse_follow(
        @out(color::Vec4),
        @uniform(time::Float32),
        @uniform(mouse::Vec2),
        @uniform(resolution::IVec2)
    )
        frag_pos = gl_FragCoord["xy"]
        frag_pos["y"] = -frag_pos["y"] + resolution["y"]

        if distance(frag_pos, mouse) < 50.0f0
            f_in = time * 2.0f0
            color = Vec4(0.5f0 * (1 + sin(f_in)), 0.2f0, 0.5f0 * (1 + cos(f_in + 3.1415f0 / 2.0f0)), 1.0f0)
        else
            discard()
        end
    end,
    true
)
