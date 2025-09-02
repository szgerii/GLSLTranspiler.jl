module GLSLPreprocessor

import JuliaGLM
using ....GLSLTranspiler
using ..GLSL
using ....BaseTypes
using ....Utils
using ....SymbolResolution

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
