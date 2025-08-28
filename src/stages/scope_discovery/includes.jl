module ScopeDiscovery

using ..BaseTypes
using ..Utils
using Tagger

include("types/Scope.jl")
include("types/ScopedASTNode.jl")
include("types/SDContext.jl")

include("rules.jl")
include("transformations.jl")
include("traversal.jl")
include("run.jl")

const ScopeDiscoveryStage =
    Stage(
        "Scope Discovery (AST -> Scoped AST)",
        run_sd;
        output_names=["Scoped AST", "Scope Tree"],
        output_formatters=[identity, scope_tree_string]
    )

end
