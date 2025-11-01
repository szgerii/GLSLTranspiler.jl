module GLSLPreprocessor

using ...Transpiler
using ...CoreTypes
using ...Utils
using ...SymbolResolution
using ...TypeInference
using ..GLSL

using StaticArrays
import JuliaGLM

include("traversal.jl")
include("run.jl")

const GLSLPreprocessorStage =
    Stage(
        "GLSL Preprocessor (AST -> AST)",
        run_glsl_preprocessor;
        run_before_definition=true,
        print_ctx=true
    )

end
