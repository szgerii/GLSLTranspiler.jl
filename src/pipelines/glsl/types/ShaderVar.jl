export ShaderVar, ShaderVarScope

@enum ShaderVarScope Global Local

struct ShaderVar{T<:ASTType}
    name::Symbol
    type::T
    scope::ShaderVarScope
    qualifiers::Vector{Qualifier}
end
