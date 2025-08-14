export type_from_ast, try_type_from_ast

function try_type_from_ast(ex::Expr, mod::Module)::Union{DataType,Nothing}
    function structure_error()
        ast_error(ex, "Invalid expression structure for type resolution (target module: $mod)")
    end

    if ex.head != :(.)
        structure_error()
    end

    location_chain = []

    iter = ex
    while iter isa Expr && iter.head == :(.)
        if length(iter.args) != 2 || !(iter.args[2] isa QuoteNode)
            structure_error()
        end

        pushfirst!(location_chain, iter.args[2].value)

        if iter.args[1] isa Symbol
            pushfirst!(location_chain, iter.args[1])
        end

        iter = ex.args[1]
    end

    @assert !isempty(length(location_chain)) && all(s -> s isa Symbol, location_chain)

    iter = mod
    for loc in location_chain[1:end]
        if !isdefined(iter, loc)
            return nothing
        end

        getfield(iter, loc)
    end

    if !(iter isa DataType)
        ast_error(ex, "AST symbol chain didn't resolve to a type")
    end

    iter
end

try_type_from_ast(sym::Symbol, mod::Module)::Union{DataType,Nothing} =
    isdefined(mod, sym) ? getfield(mod, sym) : nothing

function type_from_ast(node::Union{Expr,Symbol}, mod::Module)::DataType
    result = try_type_from_ast(node, mod)

    if isnothing(result)
        ast_error(node, "Couldn't resolve type from AST node in module $mod")
    end

    result
end
