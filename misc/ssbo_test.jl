using Transpiler
using Transpiler.GLSL
using JuliaGLM

Transpiler.transpiler_config.gl_block_conflict = Transpiler.BCS_Overwrite
Transpiler.transpiler_config.gl_rewrite_to_glm = false

@interface TestBuffer (x::Int, @coherent(y::Float32), @readonly @volatile v3::Vec3)

add_qualifier!(:TestBuffer, LayoutQualifier([LayoutQualifierOption(:std430), LayoutQualifierOption(:binding, 0)]))

code = @glsl(
    function test_compute(
        @local_size(256),
        @buffer(TestBuffer),
        @uniform(N::UInt32),
        @uniform(p::Vec3),
        @uniform(r::Float32)
    )
        function curve(t::Float32)
            x = t
            y = sin(t) * r
            z = cos(t) * r

            return p + Vec3(x, y, z)
        end

        id = gl_GlobalInvocationID[:x]
        if id >= N
            return
        end

        result = curve(0.0)
    end,
    #Transpiler.Verbose
)

println(code)
