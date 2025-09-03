export @in, @out, @uniform

macro in(decl)
    @assert decl isa Expr && decl.head == :(::)

    Expr(:glsl_var, QuoteNode(:in), QuoteNode(decl.args[1]), QuoteNode(decl.args[2]))
end

macro out(decl)
    @assert decl isa Expr && decl.head == :(::)

    Expr(:glsl_var, QuoteNode(:out), QuoteNode(decl.args[1]), QuoteNode(decl.args[2]))
end

macro uniform(decl)
    @assert decl isa Expr && decl.head == :(::)

    Expr(:glsl_var, QuoteNode(:uniform), QuoteNode(decl.args[1]), QuoteNode(decl.args[2]))
end
