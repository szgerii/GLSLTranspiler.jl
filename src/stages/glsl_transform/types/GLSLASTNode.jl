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

@exported struct GLSLLiteral <: GLSLASTNode
    value::ASTLiteral
    type::DataType

    GLSLLiteral(value::ASTLiteral, ::Type{T}) where {T<:GLSLType} = new(value, T)
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

export GLSLStorageQualifier, SQ_In, SQ_None, SQ_Out, SQ_Uniform
@enum GLSLStorageQualifier SQ_None SQ_In SQ_Out SQ_Uniform

to_storage_qualifier(sym::Symbol) = to_storage_qualifier(Val(sym))
to_storage_qualifier(::Val{:in}) = SQ_In
to_storage_qualifier(::Val{:out}) = SQ_Out
to_storage_qualifier(::Val{:uniform}) = SQ_Uniform

@exported struct GLSLDeclaration <: GLSLASTNode
    symbol::GLSLSymbol
    type::DataType
    storage_qualifier::GLSLStorageQualifier

    GLSLDeclaration(sym::GLSLSymbol, ::Type{T}, qualifier::GLSLStorageQualifier=SQ_None) where {T<:GLSLType} =
        new(sym, T, qualifier)
end

@exported struct GLSLShader <: GLSLASTNode
    interface_declarations::Vector{GLSLDeclaration}
    body::GLSLBlock
end

@exported struct GLSLSwizzle <: GLSLASTNode
    base::GLSLASTNode
    swizzle::String
end

precomp_subtypes(GLSLASTNode, GLSLSwizzle, (missing, String))

@exported struct GLSLAssignment <: GLSLASTNode
    lhs::Union{GLSLSymbol,GLSLSwizzle}
    rhs::GLSLASTNode

    function GLSLAssignment(lhs::Union{GLSLSymbol,GLSLSwizzle}, rhs::GLSLASTNode)
        @assert lhs isa GLSLSymbol || length(lhs.swizzle) == 1
        new(lhs, rhs)
    end
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
