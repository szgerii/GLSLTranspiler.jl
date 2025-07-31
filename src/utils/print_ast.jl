export @print_ast, print_tast

function print_ast(f::Expr)
    f.head == :function || ast_error(f, "Attempting to use @print_ast for a non-function expression")

    @assert length(f.args) > 0
    @assert f.args[2].head == :block

    Base.remove_linenums!(f)

    traverse_print(f)
end

function traverse_print(node::ASTNode, indent=0)
    typ = typeof(node)
    padding = repeat(' ', indent)
    output = string(node)
    if isa(node, Expr)
        output = string(node.head)
    end
    println("$padding$typ: $output")

    if isa(node, Expr)
        for child in node.args
            traverse_print(child, indent + 2)
        end
    end
end

function traverse_print(node::TypeTree, indent=0)
    typ = node.type
    padding = repeat(' ', indent)
    output = isa(node.original[], Expr) ? string(node.original[].head) : string(node.original[])

    println("$padding$typ: $output")

    for child in node.children
        traverse_print(child, indent + 2)
    end
end

print_tast(root::TypeTree) = traverse_print(root)
