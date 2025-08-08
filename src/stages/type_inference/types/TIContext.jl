mutable struct TIContext
    defining_module::Module
    root_scope::Ref{Scope}
    # DataType must be <: ASTValueType
    typed_usyms::Vector{Tuple{UniqueSymbol,Union{DataType,Nothing}}}
    usym_table::ScopedUSymMapping
    return_type::DataType
end

find_usym_index(usym_id::Symbol, ctx::TIContext)::Union{Int,Nothing} =
    findfirst(typed_usym -> typed_usym[1].id == usym_id, ctx.typed_usyms)

find_usym_index(usym::UniqueSymbol, ctx::TIContext) = find_usym_index(usym.id, ctx)

function find_type(usym_id::Symbol, ctx::TIContext)::Union{<:ASTValueType,Nothing}
    idx = find_usym_index(usym_id, ctx)
    !isnothing(idx) ? ctx.typed_usyms[idx][2] : nothing
end

find_type(usym::UniqueSymbol, ctx::TIContext) = find_type(usym, ctx)

function add_type!(ctx::TIContext, usym_id::Symbol, ::Type{T}) where {T<:Union{ASTValueType,ASTFunction}}
    idx = find_usym_index(usym_id, ctx)

    @assert isnothing(ctx.typed_usyms[idx][2])

    ctx.typed_usyms[idx] = (ctx.typed_usyms[idx][1], T)
end

add_type!(ctx::TIContext, usym::UniqueSymbol, ::Type{T}) where {T<:Union{ASTValueType,ASTFunction}} = add_type!(ctx, usym.id, T)
