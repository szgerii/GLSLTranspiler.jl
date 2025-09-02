export ASTLiteral, ASTNode, ASTNodeRef

const ast_literal_types = [Float64, Float32, Int64, Int32, String, Char, Bool, Nothing]

const ASTLiteral = Union{ast_literal_types...}
const ASTNode = Union{Expr,Symbol,QuoteNode,LineNumberNode,ASTLiteral}
const ASTNodeRef = Union{map(T -> Ref{T}, unwrap_union(ASTNode))...}
