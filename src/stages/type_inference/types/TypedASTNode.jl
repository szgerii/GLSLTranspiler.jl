@exported mutable struct TypedASTNode <: WrapperTree
    children::Vector{TypedASTNode}
    original::ASTNodeRef
    scope::Ref{Scope}
    has_own_scope::Bool
    type::DataType

    function TypedASTNode(
        children::Vector{TypedASTNode}, original::ASTNodeRef, scope::Ref{Scope}, has_own_scope::Bool, ::Type{T}
    ) where {T<:ASTType}
        new(children, original, scope, has_own_scope, T)
    end
end

TypedASTNode(base::ScopedASTNode, ::Type{T}) where {T<:ASTType} =
    TypedASTNode(Vector{TypedASTNode}(), base.original, base.scope, base.has_own_scope, T)

precomp_subtypes(ASTType, TypedASTNode, (ScopedASTNode, missing))

TypedASTNode(base::ScopedASTNode) = TypedASTNode(base, ASTVoid)

CoreTypes.tree_node_string(node::TypedASTNode) = "[$(node.type)]\n" * CoreTypes.tree_node_string(node.original[])
