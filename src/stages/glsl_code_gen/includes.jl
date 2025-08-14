module GLSLCodeGen

using ....GLSLTranspiler.BaseTypes
using ..GLSL.GLSLTransform
using ..GLSL
using Tagger

include("types/GLSLCodeGenContext.jl")
include("type_to_str.jl")
include("qualifier_to_str.jl")
include("traversal.jl")
include("run.jl")

const GLSLCodeGenStage =
    Stage(
        "GLSL Code Generation (GLSL AST -> String)",
        run_glsl_code_gen;
        output_names=["Generated GLSL Code"],
        output_formatters=[identity]
    )

end