# TODO: def line, is_static, scope type? (param?, local, global)

struct VarData
    name::String
    type::DataType

    VarData(name::String, ::Type{T}) where {T<:TASTLiteral} = new(name, T)
end
