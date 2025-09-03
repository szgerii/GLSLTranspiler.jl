export print_tree, tree_node_string

tree_node_string(node::ASTNode) = string(typeof(node), ": ", node)
tree_node_string(node::Expr) = string(typeof(node), ": ", node.head)
tree_node_string(node::T) where {T<:WrapperTree} = tree_node_string(get_original(node)[])

print_tree(misc, indent=0) = println(repeat(' ', indent), misc)

function print_tree(node::ASTNode, indent=0)
    padding = repeat(' ', indent)
    node_str = tree_node_string(node)
    println(padding, node_str)

    if isa(node, Expr)
        for child in node.args
            print_tree(child, indent + 2)
        end
    end
end

function print_tree(node::T, indent=0) where {T<:WrapperTree}
    padding = repeat(' ', indent)
    node_str = tree_node_string(node)
    node_str = replace(node_str, "\n" => "\n$padding")

    println(padding, node_str)

    for child in get_children(node)
        print_tree(child, indent + 2)
    end
end
