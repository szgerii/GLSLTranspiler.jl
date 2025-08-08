abstract type ASTType end

struct ASTInt32 <: ASTType end
struct ASTInt64 <: ASTType end
struct ASTFloat32 <: ASTType end
struct ASTFloat64 <: ASTType end
struct ASTBool <: ASTType end
struct ASTChar <: ASTType end
struct ASTString <: ASTType end

struct ASTFunction <: ASTType end
struct ASTVoid <: ASTType end
struct ASTVoidSym <: ASTType end

Base.string(::Type{T}) where {T<:ASTType} = string(nameof(T))
Base.show(io::IO, ::Type{T}) where {T<:ASTType} = print(io, string(nameof(T)))

const tast_value_types = [ASTInt32, ASTInt64, ASTFloat32, ASTFloat64, ASTBool, ASTChar, ASTString]

const ASTValueType = Union{tast_value_types...}

is_void(::Type{ASTVoid}) = true
is_void(::Type{ASTVoidSym}) = true
is_void(::Type{<:ASTType}) = false

macro define_tast_bijection(ast_type::Symbol, tast_type::Symbol)
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

# type constructors like Int64(...)
to_tast(::Type{DataType}) = ASTFunction

@define_tast_bijection Int32 ASTInt32
@define_tast_bijection Int64 ASTInt64
@define_tast_bijection Float32 ASTFloat32
@define_tast_bijection Float64 ASTFloat64
@define_tast_bijection Bool ASTBool
@define_tast_bijection Char ASTChar
@define_tast_bijection String ASTString
@define_tast_bijection Nothing ASTVoid
