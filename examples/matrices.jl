using Pkg
Pkg.activate(@__DIR__() * "/../")

using Transpiler
using Transpiler.GLSL
using JuliaGLM

code = @transpile(
    Transpiler.GLSL.glsl_pipeline,
    function matrices(@out(frag_col::Vec4))
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
