module TypeInference

using ..GLSLTranspiler.BaseTypes
using ..GLSLTranspiler.ScopeDiscovery
using ..GLSLTranspiler.SymbolResolution
using Tagger

include("types/TASTNodeTypes.jl")
include("types/TypedASTNode.jl")
include("types/TIContext.jl")

include("rules.jl")
include("transformations.jl")
include("traversal.jl")
include("run.jl")

const TypeInferenceStage = Stage("Type Inference (Scoped AST with usyms -> Typed AST)", run_type_inference)

end
