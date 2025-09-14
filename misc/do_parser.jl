# Just some playing around with getting proper functions definitions from the 'do' syntax
# This could be useful for integration into Juliagebra

macro parse_do(fn_call::Expr)
    @assert fn_call.head == :do && length(fn_call.args) == 2

    Base.remove_linenums!(fn_call)

    lambda_fn = fn_call.args[2]

    @assert lambda_fn isa Expr && lambda_fn.head == :(->) && length(lambda_fn.args) == 2

    params = lambda_fn.args[1]
    body = lambda_fn.args[2]

    fn = Expr(:function, params, body)
    println("Parsed do block:")
    dump(fn)
    __module__.eval(quote
        $fn(1, 2)
    end)

    :($(esc(fn_call)))
end

test(f, x, y) = f(x, y)

x = 2

@parse_do test(1, 2) do a::Int, b
    println(a + b + x)
end
