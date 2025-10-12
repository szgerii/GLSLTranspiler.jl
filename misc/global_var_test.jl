using Transpiler
using Transpiler.GLSL

x = 2
z = 1

(_, code) = Transpiler.run_pipeline(
    Transpiler.GLSL.GLSLPipeline,
    :(
        function test()
            function helper()
                z
            end

            y = x
            w = helper()
        end
    ),
    @__MODULE__();
#    log_level=Transpiler.Verbose
)

println(code)