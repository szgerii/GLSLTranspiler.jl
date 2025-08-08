import ..GLSLTranspiler

export ScopedASTNode

mutable struct ScopedASTNode <: WrapperTree
    original::ASTNodeRef
    children::Vector{<:ScopedASTNode}
    scope::Ref{Scope}
    has_own_scope::Bool
end

ScopedASTNode(original::ASTNodeRef, scope::Ref{Scope}, has_own_scope::Bool=false) =
    ScopedASTNode(original, Vector{ScopedASTNode}(), scope, has_own_scope)

function GLSLTranspiler.tree_node_string(node::ScopedASTNode)
    prefix = ""

    # print scope information for global scope before the base fn def node
    ast_node = node.original[]
    if ast_node isa Expr && ast_node.head == :function && node.scope[].id_chain == FUNCTION_SCOPE_ID
        prefix = "[" * string(node.scope[].parent[]) * "]\n"
    end

    prefix *
    (node.has_own_scope ?
     string("[", string(node.scope[]), "]\n", GLSLTranspiler.tree_node_string(get_original(node)[])) :
     GLSLTranspiler.tree_node_string(get_original(node)[]))
end
