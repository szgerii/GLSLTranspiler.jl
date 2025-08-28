function ast_error(node::ASTNode, message...)
    str = ast_string(node)

    error(message..., "\nThe above error occured while processing the following AST node:\n$str")
end

function ast_string(ex::Expr)
    str = ':' * string(ex.head)

    for arg in ex.args
        str *= "\n  "

        if arg isa Expr
            str *= "Expr (:$(arg.head))"
        else
            str *= ast_string(arg)
        end
    end

    str
end

ast_string(sym::Symbol) = ":$sym"
ast_string(str::String) = "\"$str\""
ast_string(node::ASTNode) = string(node)
