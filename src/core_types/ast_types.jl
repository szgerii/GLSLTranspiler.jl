export ASTLiteral, ASTNode, ASTNodeRef

const ast_literal_types = [
    Float64, Float32,
    Int64, Int32,
    UInt64, UInt32,
    String, Char,
    Bool, Nothing
]

const ASTLiteral = Union{ast_literal_types...}
const ASTNode = Union{Expr,Symbol,QuoteNode,GlobalRef,LineNumberNode,ASTLiteral,DataType,Vector}
const ASTNodeRef = Union{map(T -> Ref{T}, Base.uniontypes(ASTNode))...,Ref{<:DataType},Ref{<:Vector}}
