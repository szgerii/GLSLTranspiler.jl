export ASTLiteral, ASTNode, ASTNodeRef

const ast_literal_types = [
    Float64, Float32,
    Int64, Int32,
    UInt64, UInt32,
    String, Char,
    Bool, Nothing, Missing
]

"""
A Union type for literals recognized by the transpiler
"""
const ASTLiteral = Union{ast_literal_types...}

"""
A general Union type for possible node types in the Julia AST
"""
const ASTNode = Union{Expr,Symbol,QuoteNode,GlobalRef,LineNumberNode,ASTLiteral,DataType,Vector}
"""
A general Union type for references to node types in the Julia AST
"""
const ASTNodeRef = Union{map(T -> Ref{T}, Base.uniontypes(ASTNode))...,Ref{<:DataType},Ref{<:Vector}}
