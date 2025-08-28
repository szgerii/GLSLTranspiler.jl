module TypeInference

using ..GLSLTranspiler
using ..BaseTypes
using ..Utils
using ..ScopeDiscovery
using ..SymbolResolution
using Tagger
using JuliaGLM

include("types/TASTNodeTypes.jl")
include("types/TypedUniqueSymbol.jl")
include("types/TypedASTNode.jl")
include("types/TIContext.jl")

include("rules.jl")
include("transformations.jl")
include("traversal.jl")
include("run.jl")

const TypeInferenceStage =
    Stage(
        "Type Inference (Scoped AST with usyms -> Typed AST)",
        run_type_inference;
        output_names=["Typed AST", "Scope Tree", "Typed Unique Symbols"],
        output_formatters=[identity, _ -> nothing, typed_usym_list_string]
    )

end
