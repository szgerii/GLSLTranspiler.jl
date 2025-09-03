export get_param_names, resolve_module_chain, ast_error, try_type_from_ast, type_from_ast

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

function ast_error(node::WrapperTree, message...)
    ast_error(get_original(node)[], message...)
end

ast_string(sym::Symbol) = ":$sym"
ast_string(str::String) = "\"$str\""
ast_string(node::ASTNode) = string(node)

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
