using GLSLTranspiler
using GLSLTranspiler.GLSL

x = 2
z = 1

(_, code) = GLSLTranspiler.run_pipeline(
    GLSLTranspiler.GLSL.GLSLPipeline,
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
    #    log_level=GLSLTranspiler.Verbose
)

println(code)