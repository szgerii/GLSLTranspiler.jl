function preprocess_ast(f::Expr, mod::Module)::Expr
    @assert f.head == :function

    Base.remove_linenums!(f)

    f.args[2] = preprocess_node(f.args[2], mod)

    f
end

function preprocess_node(node::Expr, mod::Module)::ASTNode
    for i in 1:length(node.args)
        node.args[i] = preprocess_node(node.args[i], mod)
    end

    node = preprocess_transform(tag_match(PreTag, node), node, mod)

    node
end

preprocess_node(node::Any, _::Module)::ASTNode = node
