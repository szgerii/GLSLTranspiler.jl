export USymMapping, ScopedUSymMapping

const USymMapping = Dict{Symbol,Symbol}
const ScopedUSymMapping = Dict{IDChain,USymMapping}

struct SRContext
    defining_module::Module
    root_scope::Ref{Scope}
    scoped_sym_usages::ScopedSymbolUsageTable
    usyms::Dict{Symbol,UniqueSymbol} # usym_id => UniqueSymbol
    usym_mappings::ScopedUSymMapping
    env_syms::Vector{Symbol}
end

SRContext(defining_module::Module, root_scope::Ref{Scope}) =
    SRContext(defining_module, root_scope, ScopedSymbolUsageTable(), Dict(), ScopedUSymMapping(), Vector())

function reg_env_usym!(ctx::SRContext, sym::Symbol)::UniqueSymbol
    usym = UniqueSymbol(sym, sym, FUNCTION_SCOPE_ID)

    @assert !haskey(ctx.usyms, sym) "Trying to re-register environment symbol: $sym"

    push!(ctx.env_syms, sym)
    ctx.usyms[sym] = usym

    usym
end

function reg_usym!(ctx::SRContext, sym::Symbol, scope_id::IDChain)::UniqueSymbol
    usym_id = get_usym_id(sym, scope_id)
    usym = UniqueSymbol(usym_id, sym, scope_id)

    @assert !haskey(ctx.usyms, usym_id) "Trying to re-register a unique symbol that has already been registered (sym: $sym, scope id: $(id_chain_string(scope_id)))"

    ctx.usyms[usym_id] = usym

    usym
end

reg_usym!(ctx::SRContext, sym::Symbol, scope::Scope) = reg_usym!(ctx, sym, scope.id_chain)
reg_usym!(ctx::SRContext, sym::Symbol, scope::Ref{Scope}) = reg_usym!(ctx, sym, scope[])

function add_mapping!(ctx::SRContext, sym::Symbol, scope_id::IDChain, usym::UniqueSymbol)
    if !haskey(ctx.usym_mappings, scope_id)
        ctx.usym_mappings[scope_id] = USymMapping()
    end

    prev_mapping = get(ctx.usym_mappings[scope_id], sym, nothing)
    if !isnothing(prev_mapping) && usym.id != prev_mapping
        error(
            "Trying to modify mapping for $sym => $(prev_mapping) in scope #$(id_chain_string(scope_id)) to $(usym.id)",
        )
    end

    ctx.usym_mappings[scope_id][sym] = usym.id
end

add_mapping!(ctx::SRContext, sym::Symbol, scope::Ref{Scope}, usym::UniqueSymbol) =
    add_mapping!(ctx, sym, scope[].id_chain, usym)

function find_usym_in_parents(sym::Symbol, id_chain::IDChain, ctx::SRContext)::Union{UniqueSymbol,Nothing}
    for (_, usym) in ctx.usyms
        if sym == usym.original_sym &&
           (id_chain == usym.def_scope_id || is_parent_of(id_chain, usym.def_scope_id))
            return usym
        end
    end

    return nothing

    # go upwards the scope tree, excluding the global scope
    for i in length(id_chain):-1:1
        id_snippet = id_chain[1:i]

        usym = get(ctx.usyms, get_usym_id(sym, id_snippet), nothing)
        if !isnothing(usym)
            return usym
        end
    end

    return nothing
end

find_usym_in_parents(sym::Symbol, scope::Ref{Scope}, ctx::SRContext) = find_usym_in_parents(sym, scope[].id_chain, ctx)
