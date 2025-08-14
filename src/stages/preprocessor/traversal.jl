function preprocess_traverse(node::Expr, mod::Module)::Vector{ASTNode}
    i = 1
    while i <= length(node.args)
        result_nodes = preprocess_traverse(node.args[i], mod)

        if length(result_nodes) == 0
            popat!(node.args, i)
            continue
        end

        node.args[i] = result_nodes[1]

        for (j, result_node) in enumerate(result_nodes[2:end])
            insert!(node.args, i + j, result_node)
        end

        i += 1
    end

    preprocess_transform(tag_match(PreTag, node), node, mod)
end

preprocess_traverse(node::ASTNode, _::Module)::Vector{ASTNode} = [node]
