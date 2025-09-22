using Pkg
Pkg.activate(@__DIR__() * "/../")

using Transpiler
using Transpiler.GLSL

x = 2
z = 1

(_, code) = Transpiler.run_pipeline(
    Transpiler.GLSL.glsl_pipeline,
    :(
        function test()
            function helper()
                z
            end

            y = x
        end
    ),
    @__MODULE__();
    log_level=Transpiler.Verbose
)

println(code)