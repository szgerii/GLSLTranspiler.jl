mutable struct TypeTree
    type::DataType
    children::Vector{<:TypeTree}
    original::ASTNodeRef

    function TypeTree(::Type{T}, children::Vector{TypeTree}, original::ASTNodeRef) where {T<:TASTNode}
        new(T, children, original)
    end
end

TypeTree(::Type{T}, root::ASTNodeRef) where {T<:TASTNode} = TypeTree(T, Vector{TypeTree}(), root)
TypeTree(root::ASTNodeRef) = TypeTree(TASTVoid, root)
