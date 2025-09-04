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


@skip code = @transpile(
    Transpiler.GLSL.glsl_pipeline,
    function fn_test(@out(frag_col::Vec4))
        function helper(a::Int)
            a
        end

        v = Vec4(1)
        v[:xy] = Vec2(1)

        x = helper(2)

        frag_col = vec4(1)
    end,
    false
)

@skip code = @transpile(
    Transpiler.GLSL.glsl_pipeline,
    function range_test()
        a = 3

        local @constant x::Int
        x = 2

        #acc = 0
        #n = 5
        #for i in 1:n
        #    acc += i
        #end

        #while n > 10
        #    acc += n
        #end
        x + 2
    end,
    false
)


@skip Transpiler.Preprocessor.PreprocessorStage.run(
    @__MODULE__(), Transpiler.CoreTypes.init_pipeline_ctx(Transpiler.GLSL.GLSLPipelineContext),
    :(function preprocessor_test()
        x, y, z = 1, 2, 3

        cos.(vec3(1))

        if x < y < z
            x += y
        end
    end)
)

some_global = 1
some_other_global = 1

code = @transpile(
    Transpiler.GLSL.glsl_pipeline, function type_example()
        x = 1.0
        y = 2.0

        z = x + y

        mat = mat2x3(0)
        t_mat = mat'
    end,
    true
)




println(code)


