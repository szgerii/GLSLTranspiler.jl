module GLSLPreprocessor

using ....GLSLTranspiler
using ....GLSLTranspiler.GLSL
using ....GLSLTranspiler.BaseTypes
using ....GLSLTranspiler.SymbolResolution

include("run.jl")

const GLSLPreprocessorStage =
    Stage(
        "GLSL Preprocessor (AST -> AST)",
        run_glsl_preprocessor;
        run_before_definition=true,
        print_ctx=true
    )

end
