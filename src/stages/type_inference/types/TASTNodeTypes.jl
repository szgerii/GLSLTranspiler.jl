import ..GLSLTranspiler

export ASTValueType

@exported abstract type ASTType end

@exported struct ASTInt32 <: ASTType end
@exported struct ASTInt64 <: ASTType end
@exported struct ASTUInt32 <: ASTType end
@exported struct ASTUInt64 <: ASTType end
@exported struct ASTFloat32 <: ASTType end
@exported struct ASTFloat64 <: ASTType end
@exported struct ASTBool <: ASTType end
@exported struct ASTChar <: ASTType end
@exported struct ASTString <: ASTType end

@exported struct ASTVec2 <: ASTType end
@exported struct ASTVec3 <: ASTType end
@exported struct ASTVec4 <: ASTType end

@exported struct ASTFunction <: ASTType end
@exported struct ASTVoid <: ASTType end
@exported struct ASTVoidSym <: ASTType end

Base.string(::Type{T}) where {T<:ASTType} = string(nameof(T))
Base.show(io::IO, ::Type{T}) where {T<:ASTType} = print(io, string(nameof(T)))

const tast_value_types =
    [ASTInt32, ASTInt64, ASTUInt32, ASTUInt64, ASTFloat32, ASTFloat64, ASTBool, ASTChar, ASTString, ASTVec2, ASTVec3, ASTVec4]

const ASTValueType = Union{tast_value_types...}

@exported struct ASTRange{T<:ASTValueType} <: ASTType end
Base.eltype(::Type{ASTRange{T}}) where T = T
Base.eltype(_::ASTRange{T}) where T = T

is_void(::Type{ASTVoid}) = true
is_void(::Type{ASTVoidSym}) = true
is_void(::Type{<:ASTType}) = false

macro define_tast_bijection(ast_type, tast_type)
    quote
        # TAST -> AST
        $(esc(:to_ast))(::Type{$(esc(tast_type))}) = $(esc(ast_type))
        # AST -> TAST
        $(esc(:to_tast))(::Type{$(esc(ast_type))}) = $(esc(tast_type))
    end
end

to_ast(::Type{T}) where {T<:ASTValueType} = nothing

to_tast(::Type{T}) where T = error("Found value of unsupported type: ", T)
to_tast(::Type{T}) where {T<:ASTLiteral} = nothing
to_tast(::Type{<:Function}) = ASTFunction

to_tast(::Type{UnitRange{T}}) where T = ASTRange{to_tast(T)}
to_tast(::Type{StepRange{T,T}}) where T = ASTRange{to_tast(T)}
function to_tast(::Type{StepRange{T,S}}) where {T,S}
    type = promote_type(T, S)

    if !isconcretetype(type)
        error("Cannot transpile step ranges whose element and spacing types cannot be promoted to a single type using promote_type")
    end

    to_tast(StepRange{type,type})
end

# type constructors like Int64(...)
to_tast(::Type{DataType}) = ASTFunction

@define_tast_bijection Int32 ASTInt32
@define_tast_bijection Int64 ASTInt64
@define_tast_bijection UInt32 ASTUInt32
@define_tast_bijection UInt64 ASTUInt64
@define_tast_bijection Float32 ASTFloat32
@define_tast_bijection Float64 ASTFloat64
@define_tast_bijection Bool ASTBool
@define_tast_bijection Char ASTChar
@define_tast_bijection String ASTString
@define_tast_bijection GLSLTranspiler.Vec2T{Float32} ASTVec2
@define_tast_bijection GLSLTranspiler.Vec3T{Float32} ASTVec3
@define_tast_bijection GLSLTranspiler.Vec4T{Float32} ASTVec4
@define_tast_bijection Nothing ASTVoid
