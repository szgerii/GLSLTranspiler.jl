export ASTLiteral, ASTNode, ASTNodeRef

unwrap_union(::Type{T}) where T = T isa Union ? vcat([T.a], unwrap_union(T.b)) : [T]

const ast_literal_types = [Float64, Float32, Int64, Int32, String, Char, Bool, Nothing]

const ASTLiteral = Union{ast_literal_types...}
const ASTNode = Union{Expr,Symbol,QuoteNode,LineNumberNode,ASTLiteral}
const ASTNodeRef = Union{map(T -> Ref{T}, unwrap_union(ASTNode))...}
