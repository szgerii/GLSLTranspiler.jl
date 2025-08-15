const GenType = Union{ASTVecNF,ASTFloat32}
const GenDType = Union{ASTVecND,ASTFloat64}
const GenIType = Union{ASTVecNI,ASTInt32}
const GenBType = Union{ASTVecNB,ASTBool}
const GenUType = Union{ASTVecNU,ASTUInt32}

const GLSLCtx = GLSLPipelineContext

BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:discard}) = ASTVoid

BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:cos}, ::Type{T}) where {T<:GenType} = T
BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:sin}, ::Type{T}) where {T<:GenType} = T
BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:tan}, ::Type{T}) where {T<:GenType} = T
BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:atan}, ::Type{T}) where {T<:GenType} = T
BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:atan}, ::Type{T}, ::Type{T}) where {T<:GenType} = T

BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:distance}, ::Type{T}, ::Type{T}) where {T<:GenType} = ASTFloat32
BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:distance}, ::Type{T}, ::Type{T}) where {T<:GenDType} = ASTFloat64

BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:length}, ::Type{T}, ::Type{T}) where {T<:GenType} = ASTFloat32
BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:length}, ::Type{T}, ::Type{T}) where {T<:GenDType} = ASTFloat64

BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:exp}, ::Type{T}) where {T<:GenType} = T
BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:abs}, ::Type{T}) where {T<:Union{GenType,GenDType,GenIType}} = T

BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:smoothstep}, ::Type{T}, ::Type{T}, ::Type{T}) where {T<:Union{GenType,GenDType}} = T
BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:smoothstep}, ::Type{ASTFloat32}, ::Type{ASTFloat32}, ::Type{T}) where {T<:GenType} = T
BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:smoothstep}, ::Type{ASTFloat64}, ::Type{ASTFloat64}, ::Type{T}) where {T<:GenDType} = T

BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:mix}, ::Type{T}, ::Type{T}, ::Type{T}) where {T<:Union{GenType,GenDType,GenBType}} = T
BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:mix}, ::Type{T}, ::Type{T}, ::Type{ASTFloat32}) where {T<:GenType} = T
BaseTypes.env_fn_ret(::Type{GLSLCtx}, _::Val{:mix}, ::Type{T}, ::Type{T}, ::Type{ASTFloat64}) where {T<:GenType} = T
BaseTypes.env_fn_ret(
    ::Type{GLSLCtx}, _::Val{:mix}, ::Type{T}, ::Type{T}, ::Type{S}
) where {T<:Union{GenType,GenDType,GenIType,GenUType},S<:GenBType} = T
