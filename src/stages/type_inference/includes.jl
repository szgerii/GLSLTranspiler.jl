module TypeInference

using ..GLSLTranspiler.BaseTypes
using ..GLSLTranspiler.ScopeDiscovery
using ..GLSLTranspiler.SymbolResolution
using Tagger

include("types/TASTNodes.jl")
include("types/VarData.jl")
include("types/TypeTree.jl")

include("rules.jl")
include("transformations.jl")
include("traversal.jl")
include("run.jl")

end
