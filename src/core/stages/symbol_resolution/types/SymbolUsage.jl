@enum SymbolUsage SymGlobalDeclaration SymLocalDeclaration SymAssignment SymAccess

is_declaration(usage::SymbolUsage) = usage == SymGlobalDeclaration || usage == SymLocalDeclaration

const SymbolUsageTable = Dict{Symbol,Vector{SymbolUsage}}
const ScopedSymbolUsageTable = Dict{IDChain,SymbolUsageTable}
