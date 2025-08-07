export AbstractTree, WrapperTree, get_children, get_original

abstract type AbstractTree end

function get_children(node::T)::Vector{<:T} where {T<:AbstractTree}
    node.children
end

abstract type WrapperTree <: AbstractTree end

function get_original(node::T)::ASTNodeRef where {T<:WrapperTree}
    node.original
end
