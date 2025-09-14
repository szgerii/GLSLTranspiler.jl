module SymbolResolution

using ..CoreTypes
using ..Utils
using ..ScopeDiscovery

using Tagger

include("types/UniqueSymbol.jl")
include("types/SymbolUsage.jl")
include("types/ScopeContext.jl")
include("types/SRContext.jl")

include("rules.jl")
include("traversal.jl")
include("gen_usyms.jl")
include("replace_with_usyms.jl")
include("run.jl")

const SymbolResolutionStage =
    Stage(
        "Symbol Resolution (Scoped AST -> Scoped AST + USYMS)",
        run_sr;
        output_names=["Scoped AST with usyms", "Scope Tree", "Unique Symbols", "Symbol Mappings"],
        output_formatters=[identity, _ -> nothing, usym_list_string, usym_mappings_string]
    )

end
