export ast_error

function ast_error(ex::Expr, message...)
    str = ':' * string(ex.head)

    for arg in ex.args
        str *= "\n  "

        if arg isa Expr
            str *= "Expr (:$(arg.head))"
        elseif arg isa Symbol
            str *= ":$(string(arg))"
        elseif arg isa String
            str *= "\"$arg\""
        else
            str *= string(arg)
        end
    end

    error(message..., "\nThe above error occured while processing the following AST node:\n$str")
end

ast_error(tt::TypeTree, message...) = ast_error(tt.original[], message...)
