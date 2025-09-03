using Pkg
Pkg.activate(@__DIR__)

macro skip(f...)
    :()
end

using Transpiler
using Transpiler.GLSL
using JuliaGLM

some_global = 2
some_other_global = 3

@skip @transpile Transpiler.GLSL.glsl_pipeline function test_fn(a::Int, b::Int)
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

@skip @transpile(
    Transpiler.GLSL.glsl_pipeline,
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
    Transpiler.GLSL.glsl_pipeline,
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
    Transpiler.GLSL.glsl_pipeline,
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
    Transpiler.GLSL.glsl_pipeline,
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
    Transpiler.GLSL.glsl_pipeline,
    function green(@out(out_col::Vec4))
        out_col = Vec4(0, 1, 0, 1)
    end
)

@skip @transpile(
    Transpiler.GLSL.glsl_pipeline,
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
    Transpiler.GLSL.glsl_pipeline,
    function mouse_follow(
        @out(color::Vec4),
        @uniform(time::Float32),
        @uniform(mouse::Vec4),
        @uniform(resolution::IVec2)
    )
        frag_pos = gl_FragCoord["xy"]
        frag_pos["y"] = -frag_pos["y"] + resolution["y"]

        dist = distance(frag_pos, mouse["xy"])
        if dist < 50.0f0
            f_in = time * 2.0f0
            color = Vec4(0.5f0 * (1 + sin(f_in)), 0.2f0, 0.5f0 * (1 + cos(f_in + 3.1415f0 / 2.0f0)), 1.0f0)
        else
            discard()
        end
    end,
    true
)

@skip code = @transpile(
    Transpiler.GLSL.glsl_pipeline,
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
    end,
    false
)

#println(code)

#Transpiler.transpiler_config.literals_as_f32 = false

# TODO: first line locals conflict with env syms (if e.g. x::Int32)
# TODO: type decls like local x::Int32
@skip code = @transpile(
    Transpiler.GLSL.glsl_pipeline,
    function test_shader(@in(a::Float32), @out(col::Vec4))
        i = 1
        m2 = mat2(1)
        f = m2[i]
        m43 = mat4x3(1)
        #v4 = m43[1, :]
        v3 = m43[:, i]
        m43_2 = m43[:, :]
    end,
    false
)

code = @transpile(
    Transpiler.GLSL.glsl_pipeline,
    function mat_test(@out(frag_col::Vec4))
        m2 = mat2(1, 2, 3, 4)
        m3 = mat3(1, 2, 3, 4, 5, 6, 7, 8, 9)
        m4 = mat4(1, 0, 0, 0, 0, 2, 0, 0, 0, 0, 3, 0, 0, 0, 0, 4)

        c0_m2 = m2[:, 1]
        c1_m3 = m3[:, 2]
        c2_m4 = m4[:, 3]

        swizzled = c1_m3[:xy][:x]
        elem = m2[1, 2]
        elem_dup = m2[3]

        mmul = m3 * m3'

        frag_col = vec4(
            c0_m2[:x] / 4.0,
            elem / 4.0,
            swizzled / 8.0,
            1.0
        )
    end
)

println(code)

@skip @transpile(
    Transpiler.GLSL.glsl_pipeline,
    function range_test()
        acc = 0
        n = 5
        for i in 1:n
            acc += i
        end

        while n > 10
            acc += n
        end
    end,
    true
)
