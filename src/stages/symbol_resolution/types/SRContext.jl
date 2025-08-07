const USymMapping = Dict{Symbol,UniqueSymbol}
const ScopedUSymMapping = Dict{IDChain,USymMapping}

struct SRContext
    defining_module::Module
    root_scope::Ref{Scope}
    scoped_sym_usages::ScopedSymbolUsageTable
    usyms::Dict{Symbol,UniqueSymbol} # usym_id => UniqueSymbol
    usym_mappings::ScopedUSymMapping
end

SRContext(defining_module::Module, root_scope::Ref{Scope}) =
    SRContext(defining_module, root_scope, ScopedSymbolUsageTable(), Dict(), ScopedUSymMapping())

function reg_usym!(ctx::SRContext, sym::Symbol, scope::Ref{Scope})::UniqueSymbol
    usym_id = get_usym_id(sym, scope)
    usym = UniqueSymbol(usym_id, sym, scope[].id_chain)

    @assert !haskey(ctx.usyms, usym_id) "Trying to re-register a unique symbol that has already been registered"

    ctx.usyms[usym_id] = usym

    usym
end

function add_mapping!(ctx::SRContext, sym::Symbol, scope::Ref{Scope}, usym::UniqueSymbol)
    id_chain = scope[].id_chain

    if !haskey(ctx.usym_mappings, id_chain)
        ctx.usym_mappings[id_chain] = USymMapping()
    end

    if haskey(ctx.usym_mappings[id_chain], sym)
        error("Trying to re-register mapping for $sym => $(usym.id) in scope #$(id_chain_string(id_chain))")
    end

    ctx.usym_mappings[id_chain][sym] = usym
end

function find_local_in_parents(sym::Symbol, id_chain::IDChain, ctx::SRContext)::Union{UniqueSymbol,Nothing}
    # go upwards the scope tree, excluding the global scope
    for i in length(id_chain):-1:2
        id_snippet = id_chain[1:i]

        usym = get(ctx.usyms, get_usym_id(sym, id_snippet), nothing)
        if !isnothing(usym)
            return usym
        end
    end

    return nothing
end

find_local_in_parents(sym::Symbol, scope::Ref{Scope}, ctx::SRContext) = find_local_in_parents(sym, scope[].id_chain, ctx)
