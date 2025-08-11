export GLSLASTNode, GLSLComment, GLSLEmptyNode, GLSLLiteral, GLSLSymbol, GLSLTypeSymbol, GLSLBlock, GLSLDeclaration,
    GLSLAssignment, GLSLCall, GLSLReturn, GLSLFor, GLSLWhile

abstract type GLSLASTNode end

struct GLSLEmptyNode <: GLSLASTNode end

struct GLSLComment <: GLSLASTNode
    content::String
    multiline::Bool
end

struct GLSLLiteral <: GLSLASTNode
    value::ASTLiteral
    type::DataType

    GLSLLiteral(value::ASTLiteral, ::Type{T}) where {T<:GLSLType} = new(value, T)
end

GLSLLiteral(value::ASTLiteral) = GLSLLiteral(value, to_glsl_type(TypeInference.to_tast(typeof(value))))

abstract type AbstractGLSLSymbol <: GLSLASTNode end

struct GLSLSymbol <: AbstractGLSLSymbol
    sym::Symbol
end

struct GLSLTypeSymbol <: AbstractGLSLSymbol
    type::DataType

    GLSLTypeSymbol(::Type{T}) where {T<:GLSLType} = new(T)
end

struct GLSLBlock <: GLSLASTNode
    body::Vector{GLSLASTNode}
end

struct GLSLDeclaration <: GLSLASTNode
    symbol::GLSLSymbol
    type::DataType

    GLSLDeclaration(sym::GLSLSymbol, ::Type{T}) where {T<:GLSLType} = new(sym, T)
end

struct GLSLAssignment <: GLSLASTNode
    lhs::GLSLSymbol
    rhs::GLSLASTNode
end

struct GLSLCall <: GLSLASTNode
    fn_name::Union{GLSLSymbol,GLSLTypeSymbol}
    args::Vector{GLSLASTNode}
end

GLSLCall(fn_name::Union{GLSLSymbol,GLSLTypeSymbol}, args::Vararg{GLSLASTNode}) = GLSLCall(fn_name, [args...])

struct GLSLReturn <: GLSLASTNode
    body::Union{GLSLASTNode,Nothing}
end

struct GLSLFor <: GLSLASTNode
    definitions::Vector{GLSLASTNode}
    condition::GLSLASTNode
    step::GLSLASTNode
    body::GLSLBlock
end

struct GLSLWhile <: GLSLASTNode
    condition::GLSLASTNode
    body::GLSLBlock
end
