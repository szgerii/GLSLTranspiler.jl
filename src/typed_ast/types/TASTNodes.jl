# TODO is there a way to do this without using REPL tools? (TASTNodeRef definition)
using InteractiveUtils

abstract type TASTNode end

struct TASTInt32 <: TASTNode end
struct TASTInt64 <: TASTNode end
struct TASTFloat32 <: TASTNode end
struct TASTFloat64 <: TASTNode end
struct TASTBool <: TASTNode end
struct TASTChar <: TASTNode end
struct TASTString <: TASTNode end

struct TASTFunction <: TASTNode end
struct TASTVoid <: TASTNode end
struct TASTVoidSym <: TASTNode end

Base.string(::Type{T}) where {T<:TASTNode} = string(nameof(T))
Base.show(io::IO, ::Type{T}) where {T<:TASTNode} = print(io, string(nameof(T)))

const tast_literal_types = [TASTInt32, TASTInt64, TASTFloat32, TASTFloat64, TASTBool, TASTChar, TASTString]

const TASTLiteral = Union{tast_literal_types...}
const TASTNodeRef = Union{map(T -> Ref{T}, subtypes(TASTNode))...}

macro define_tast_bijection(ast_type::Symbol, tast_type::Symbol)
    quote
        # TAST -> AST
        $(esc(:to_ast))(::Type{$(esc(tast_type))}) = $(esc(ast_type))
        # AST -> TAST
        $(esc(:to_tast))(::Type{$(esc(ast_type))}) = $(esc(tast_type))
    end
end

to_ast(::Type{T}) where {T<:TASTLiteral} = nothing

to_tast(::Type{T}) where {T<:ASTLiteral} = nothing
to_tast(::Type{<:Function}) = TASTFunction

@define_tast_bijection Int32 TASTInt32
@define_tast_bijection Int64 TASTInt64
@define_tast_bijection Float32 TASTFloat32
@define_tast_bijection Float64 TASTFloat64
@define_tast_bijection Bool TASTBool
@define_tast_bijection Char TASTChar
@define_tast_bijection String TASTString
@define_tast_bijection Nothing TASTVoid
