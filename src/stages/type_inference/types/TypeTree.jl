mutable struct TypeTree <: WrapperTree
    children::Vector{<:TypeTree}
    original::ASTNodeRef
    scope::Ref{Scope}
    has_own_scope::Bool
    type::DataType

    function TypeTree(
        children::Vector{TypeTree}, original::ASTNodeRef, scope::Ref{Scope}, has_own_scope::Bool, ::Type{T}
    ) where {T<:TASTNode}
        new(children, original, scope, has_own_scope, T)
    end
end

TypeTree(::Type{T}, base::ScopedASTNode) where {T<:TASTNode} = TypeTree([], base.original, base.scope, base.has_own_scope, T)
TypeTree(base::ScopedASTNode) = TypeTree(TASTVoid, base)
