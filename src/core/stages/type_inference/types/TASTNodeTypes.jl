@exported abstract type ASTType end

Base.string(::Type{T}) where {T<:ASTType} = string(nameof(T))
Base.show(io::IO, ::Type{T}) where {T<:ASTType} =
    !(T isa Union) ? print(io, string(nameof(T))) : invoke(Base.show, Tuple{IO,Union}, io, T)

# SCALARS AND OTHER VALUE TYPES

@exported struct ASTInt32 <: ASTType end
@exported struct ASTInt64 <: ASTType end
@exported struct ASTUInt32 <: ASTType end
@exported struct ASTUInt64 <: ASTType end
@exported struct ASTFloat32 <: ASTType end
@exported struct ASTFloat64 <: ASTType end
@exported struct ASTBool <: ASTType end
@exported struct ASTChar <: ASTType end
@exported struct ASTString <: ASTType end
@exported struct ASTModule <: ASTType end
@exported struct ASTSymbol <: ASTType end
@exported struct ASTFunction <: ASTType end
@exported struct ASTVoid <: ASTType end
@exported struct ASTVoidSym <: ASTType end

export is_ast_void, is_ast_integer

is_ast_void(::Type{<:Union{ASTVoid,ASTVoidSym}}) = true
is_ast_void(::Type{<:ASTType}) = false

is_ast_integer(::Type{<:Union{ASTInt32,ASTInt64,ASTUInt32,ASTUInt64}}) = true
is_ast_integer(::Type{<:ASTType}) = false

# VECTORS

export VEC_EL_TYPES, elcount, get_ast_vec_type

const VEC_EL_TYPES = [
    ("F", Float32),
    ("D", Float64),
    ("I", Int32),
    ("U", UInt32),
    ("B", Bool)
]

@exported abstract type ASTVec <: ASTType end

elcount(::Type{T}) where {T<:ASTVec} =
    error("Invalid AST vector type: $T\n", "No elcount method exists for AST vector subtype.")

get_ast_vec_type(::Type{T}, n::Int) where T = get_ast_vec_type(T, Val(n))
precomp_union_types(Union{map(t -> t[2], VEC_EL_TYPES)...}, get_ast_vec_type, (missing, Int), true)

vec_types = []
for (suffix, el_type) in VEC_EL_TYPES
    abs_sym = Symbol("ASTVecN", suffix)
    @eval @exported abstract type $abs_sym <: ASTVec end
    @eval Base.eltype(::Type{<:$abs_sym}) = $el_type

    for n in 2:4
        sym = Symbol("ASTVec", n, suffix)
        @eval @exported struct $sym <: $abs_sym end
        @eval elcount(::Type{$sym}) = $n
        @eval get_ast_vec_type(::Type{$el_type}, ::Val{$n}) = $sym

        push!(vec_types, getfield(@__MODULE__, sym))
    end
end

# MATRICES

export MAT_EL_TYPES, get_ast_mat_type

const MAT_EL_TYPES = VEC_EL_TYPES

get_ast_mat_type(::Type{T}, n::Int, m::Int) where T = get_ast_mat_type(T, Val(n), Val(m))
precomp_union_types(Union{map(t -> t[2], MAT_EL_TYPES)...}, get_ast_mat_type, (missing, Int, Int), true)

@exported abstract type ASTMat <: ASTType end

mat_types = []
for (suffix, el_type) in MAT_EL_TYPES
    abs_sym = Symbol("ASTMatNxM", suffix)
    @eval @exported abstract type $abs_sym <: ASTMat end

    for n in 2:4
        for m in 2:4
            sym = Symbol("ASTMat", n, "x", m, suffix)
            @eval @exported struct $sym <: $abs_sym end
            @eval Base.eltype(::Type{$sym}) = $el_type
            @eval get_ast_mat_type(::Type{$el_type}, ::Val{$n}, ::Val{$m}) = $sym

            push!(mat_types, getfield(@__MODULE__, sym))
        end
    end
end

@exported struct ASTList{T} <: ASTType end
Base.eltype(::Type{<:ASTList{T}}) where T = T
Base.show(io::IO, ::Type{<:ASTList{T}}) where T = print(io, "ASTList{$T}")

export ASTValueType

const ASTValueType = Union{
    ASTBool,
    ASTInt32,ASTInt64,
    ASTUInt32,ASTUInt64,
    ASTFloat32,ASTFloat64,
    ASTChar,ASTString,
    vec_types...,
    mat_types...,
    ASTList
}

export to_ast, to_tast

macro define_tast_bijection(ast_type, tast_type)
    quote
        # AST -> TAST
        $(esc(:to_tast))(::Type{$(esc(ast_type))}) = $(esc(tast_type))
        # TAST -> AST
        $(esc(:to_ast))(::Type{$(esc(tast_type))}) = $(esc(ast_type))
    end
end

to_ast(::Type{T}) where T = nothing

to_tast(::Type{T}) where T = nothing
to_tast(::Type{<:Function}) = ASTFunction

# for type constructors like Int64(...)
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
@define_tast_bijection Nothing ASTVoid
@define_tast_bijection Module ASTModule

for n in 2:4
    for (suffix, el_type) in VEC_EL_TYPES
        ast_vec_base = Symbol("Vec", n, "T")
        tast_vec = Symbol("ASTVec", n, suffix)

        @eval to_tast(::Type{<:VecNT{$n,$el_type}}) = $tast_vec
        @eval to_ast(::Type{$tast_vec}) = $ast_vec_base{$el_type}
    end
end

for n in 2:4
    for m in 2:4
        for (suffix, el_type) in MAT_EL_TYPES
            ast_mat = Symbol(suffix != "F" ? suffix : "", "Mat", n, "x", m)
            tast_mat = Symbol("ASTMat", n, "x", m, suffix)

            @eval to_tast(::Type{<:MatNxMT{$n,$m,$el_type}}) = $tast_mat
            @eval to_ast(::Type{$tast_mat}) = $ast_mat
        end
    end
end

to_tast(::Type{Vector{T}}) where T = ASTList{T}
to_ast(::Type{ASTList{T}}) where T = Vector{T}
