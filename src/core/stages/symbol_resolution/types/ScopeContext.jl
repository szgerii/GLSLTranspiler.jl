struct ScopeContext
    defining_module::Module
    target_scope::IDChain
    sym_usages::SymbolUsageTable
end

ScopeContext(defining_module::Module, target_scope::IDChain) = ScopeContext(defining_module, target_scope, SymbolUsageTable())

function add_usage!(ctx::ScopeContext, sym::Symbol, usage_type::SymbolUsage)
    get!(ctx.sym_usages, sym, [])
    push!(ctx.sym_usages[sym], usage_type)
end
