export TypedUniqueSymbol

struct TypedUniqueSymbol
    id::Symbol
    original_sym::Symbol
    def_scope_id::IDChain
    type::DataType

    TypedUniqueSymbol(base::UniqueSymbol, ::Type{T}) where {T<:Union{ASTValueType,ASTFunction}} =
        new(base.id, base.original_sym, base.def_scope_id, T)
end

Base.string(usym::TypedUniqueSymbol) = string(usym.id) * " ($(usym.type))"
Base.show(io::IO, usym::TypedUniqueSymbol) = print(io, string(usym))

precomp_union_types(Union{ASTValueType,ASTFunction}, TypedUniqueSymbol, (UniqueSymbol, missing), true)
