export AbstractTree, WrapperTree, get_children, get_original

"""
Supertype for any tree type that can be traversed using [`get_children`](@ref).
"""
abstract type AbstractTree end

"""
    get_children(node::T) -> Vector{<:T} where {T<:AbstractTree}

Returns the children of the current node of an [`AbstractTree`](@ref).

Note that by default, this accesses the `children` field of the node. For abstract trees storing their children differently, they must provide a method for this function if they want to participate in the [`AbstractTree`](@ref) 'interface' properly.
"""
function get_children(node::T)::Vector{<:T} where {T<:AbstractTree}
    node.children
end

"""
Supertype for [`AbstractTree`](@ref) subtypes who also act as wrappers for an AST. 
"""
abstract type WrapperTree <: AbstractTree end

"""
    get_original(node::{<:WrapperTree}) -> ASTNodeRef

Return the original node wrapped by this [`WrapperTree`](@ref) node.

Note that by default, this accesses the `original` field of the node. For wrapper trees storing their original reference differently, they must provide a method for this function if they want to participate in the [`WrapperTree`](@ref) 'interface' properly.
"""
function get_original(node::T)::ASTNodeRef where {T<:WrapperTree}
    node.original
end
