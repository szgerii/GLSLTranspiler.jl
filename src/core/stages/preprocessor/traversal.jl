# Traverse AST from bottom to top, with the option of a single node 'replacing itself' with multiple nodes
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

    preprocess_transform(tag_match(PreprocessorTag, node), node, mod)
end

# Rewrite 64-bit literals (2.0) to 32-bit literals (2.0f0) if enabled
preprocess_traverse(node::Float64, _::Module)::Vector{ASTNode} =
    [Transpiler.transpiler_config.literals_as_f32 ? convert(Float32, node) : node]

preprocess_traverse(node, ::Module) = [node]

precomp_union_types(ASTNode, preprocess_traverse, (missing, Module))