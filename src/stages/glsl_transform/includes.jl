module GLSLTransform

using ....GLSLTranspiler
using ....GLSLTranspiler.GLSL
using ....GLSLTranspiler.BaseTypes
using ....GLSLTranspiler.ScopeDiscovery
using ....GLSLTranspiler.TypeInference
using Tagger

include("types/GLSLType.jl")
include("types/GLSLASTNode.jl")
include("types/GLSLTransformState.jl")
include("types/GTContext.jl")

include("rules.jl")
include("transformations.jl")
include("traversal.jl")
include("run.jl")

const GLSLTransformStage = Stage(
    "GLSL AST Transformation (Typed AST -> GLSL AST)",
    run_glsl_transform;
    output_names=["GLSL AST"],
    output_formatters=[glsl_ast_string]
)

end
