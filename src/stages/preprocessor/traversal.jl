function preprocess_traverse(node::Expr, mod::Module)::ASTNode
    for i in 1:length(node.args)
        node.args[i] = preprocess_traverse(node.args[i], mod)
    end

    node = preprocess_transform(tag_match(PreTag, node), node, mod)

    node
end

preprocess_traverse(node::ASTNode, _::Module)::ASTNode = node
