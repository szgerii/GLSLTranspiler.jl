export UniqueSymbol, get_usym_id, USYM_INFIX, is_usym_id, strip_usym_id

struct UniqueSymbol
    id::Symbol
    original_sym::Symbol
    def_scope_id::IDChain
end

Base.string(usym::UniqueSymbol) = string(usym.id)
Base.show(io::IO, usym::UniqueSymbol) = print(io, string(usym))

const USYM_INFIX = "_USYM_"

get_usym_id(original_sym::Symbol, id_chain::IDChain) = Symbol(string(original_sym), USYM_INFIX, join(id_chain, '_'))
get_usym_id(original_sym::Symbol, scope::Ref{Scope}) = get_usym_id(original_sym, scope[].id_chain)

is_usym_id(str::String) = contains(str, USYM_INFIX)
is_usym_id(sym::Symbol) = is_usym_id(string(sym))

strip_usym_id(str::String) = split(str, USYM_INFIX)[1]
strip_usym_id(sym::Symbol) = strip_usym_id(string(sym)) |> Symbol
