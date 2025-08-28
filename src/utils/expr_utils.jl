export get_param_names, resolve_module_chain

function get_param_names(f::Expr)::Vector{Symbol}
    params = Vector{Symbol}()
    fdecl = f.args[1]

    for param_decl in fdecl.args[2:end]
        @assert param_decl isa Symbol || (param_decl isa Expr && param_decl.head == :(::))

        if param_decl isa Symbol
            push!(params, param_decl)
        elseif param_decl.head == :(::)
            push!(params, param_decl.args[1])
        end
    end

    params
end

function resolve_module_chain(expr::Expr, mod::Module)
    @assert expr.head == :(.)
    @assert length(expr.args) == 2
    @assert expr.args[2] isa QuoteNode

    if expr.args[1] isa Symbol
        @assert isdefined(mod, expr.args[1])

        base_mod = getfield(mod, expr.args[1])
    else
        base_mod = resolve_module_chain(expr.args[1], mod)
    end

    @assert base_mod isa Module
    @assert isdefined(base_mod, expr.args[2].value)

    getfield(base_mod, expr.args[2].value)
end
