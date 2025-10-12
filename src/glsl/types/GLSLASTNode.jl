@exported abstract type GLSLASTNode end

@exported struct GLSLEmptyNode <: GLSLASTNode end

@exported struct GLSLNewLine <: GLSLASTNode
    num_of_lines::Int
end

GLSLNewLine() = GLSLNewLine(1)

@exported struct GLSLComment <: GLSLASTNode
    content::String
    multiline::Bool
end

const GLSLLiteralValue = Union{ASTLiteral, JuliaGLM.VecNT, JuliaGLM.MatTNxM}

@exported struct GLSLLiteral <: GLSLASTNode
    value::GLSLLiteralValue
    type::DataType

    GLSLLiteral(value::GLSLLiteralValue, ::Type{T}) where {T<:GLSLType} = new(value, T)
end

GLSLLiteral(value::ASTLiteral) = GLSLLiteral(value, to_glsl_type(TypeInference.to_tast(typeof(value))))

precomp_union_types(ASTLiteral, GLSLLiteral, (missing,))

@exported abstract type AbstractGLSLSymbol <: GLSLASTNode end

@exported struct GLSLSymbol <: AbstractGLSLSymbol
    sym::Symbol
end

@exported struct GLSLTypeSymbol <: AbstractGLSLSymbol
    type::DataType

    GLSLTypeSymbol(::Type{T}) where {T<:GLSLType} = new(T)
end

@exported struct GLSLBlock <: GLSLASTNode
    body::Vector{GLSLASTNode}
end

@exported struct GLSLDeclaration <: GLSLASTNode
    symbol::GLSLSymbol
    type::DataType
    qualifiers::Vector{Qualifier}
    initial_value::Union{GLSLASTNode,Nothing}

    GLSLDeclaration(sym::GLSLSymbol, ::Type{T},
        qualifiers::Vector{Qualifier}=Qualifier[],
        initial_value::Union{GLSLASTNode,Nothing}=nothing
    ) where {T<:GLSLType} =
        new(sym, T, qualifiers, initial_value)
end

@exported struct GLSLShader <: GLSLASTNode
    interface_declarations::Vector{GLSLDeclaration}
    body::GLSLBlock
end

@exported struct GLSLFunction <: GLSLASTNode
    name::GLSLSymbol
    params::Vector{GLSLDeclaration}
    ret_type::DataType
    body::GLSLBlock

    GLSLFunction(name::GLSLSymbol, params::Vector{GLSLDeclaration}, ::Type{RetT}, body::GLSLBlock) where {RetT<:GLSLType} =
        new(name, params, RetT, body)
end

GLSLFunction(name::Symbol, params::Vector{GLSLDeclaration}, ::Type{RetT}, body::GLSLBlock) where {RetT<:GLSLType} =
    GLSLFunction(GLSLSymbol(name), params, RetT, body)

@exported struct GLSLSwizzle <: GLSLASTNode
    base::GLSLASTNode
    swizzle::String
end

precomp_subtypes(GLSLASTNode, GLSLSwizzle, (missing, String))

@exported struct GLSLAssignment <: GLSLASTNode
    lhs::Union{GLSLSymbol,GLSLSwizzle}
    rhs::GLSLASTNode
end

@exported struct GLSLCall <: GLSLASTNode
    fn_name::Union{GLSLSymbol,GLSLTypeSymbol}
    args::Vector{GLSLASTNode}
end

GLSLCall(fn_name::AbstractGLSLSymbol, args::Vararg{GLSLASTNode}) = GLSLCall(fn_name, [args...])

precomp_subtypes(AbstractGLSLSymbol, GLSLCall, (missing, Vararg{GLSLASTNode}), false)

@exported struct GLSLReturn <: GLSLASTNode
    body::Union{GLSLASTNode,Nothing}
end

@exported struct GLSLBreak <: GLSLASTNode end
@exported struct GLSLContinue <: GLSLASTNode end

@exported mutable struct GLSLIf <: GLSLASTNode
    condition::GLSLASTNode
    body::GLSLBlock
    elseif_branches::Vector{GLSLIf}
    else_branch::Union{GLSLBlock,Nothing}
end

GLSLIf(condition::GLSLASTNode, body::GLSLBlock) =
    GLSLIf(condition, body, Vector(), nothing)
GLSLIf(condition::GLSLASTNode, body::GLSLBlock, else_branch::GLSLBlock) =
    GLSLIf(condition, body, Vector(), else_branch)

@exported struct GLSLFor <: GLSLASTNode
    definitions::Vector{GLSLASTNode}
    condition::GLSLASTNode
    step::GLSLASTNode
    body::GLSLBlock
end

@exported struct GLSLWhile <: GLSLASTNode
    condition::GLSLASTNode
    body::GLSLBlock
end

@exported struct GLSLLogicalAnd <: GLSLASTNode
    lhs::GLSLASTNode
    rhs::GLSLASTNode
end

@exported struct GLSLLogicalOr <: GLSLASTNode
    lhs::GLSLASTNode
    rhs::GLSLASTNode
end

@exported struct GLSLLogicalXor <: GLSLASTNode
    lhs::GLSLASTNode
    rhs::GLSLASTNode
end

@exported struct GLSLLogicalNeg <: GLSLASTNode
    body::GLSLASTNode
end

@exported struct GLSLMatIndexer <: GLSLASTNode
    target::GLSLASTNode
    column::GLSLASTNode
    row::Union{GLSLASTNode,Nothing}
end

using InteractiveUtils

function precompile_glsl_ast(supertype=GLSLASTNode)
    for subtype in subtypes(supertype)
        if isabstracttype(subtype)
            precompile_glsl_ast(subtype)
        elseif isconcretetype(subtype)
            precompile(subtype, fieldtypes(subtype))
        end
    end
end

precompile_glsl_ast()
