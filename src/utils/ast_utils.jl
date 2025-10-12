export get_param_names, get_param, find_decl, replace_decls, resolve_module_chain, ast_error, try_type_from_ast, type_from_ast

"""
    ast_error(node::ASTNode, message...)

Throw an [`ErrorException`](@ref) using the [`error`](@ref) function with a flat represenation of `node` appended to `messages`.

# Arguments
- `node::ASTNode`: the node to use for context information
- `messages`: The messages passed to [`error`](@ref), with `node` ctx info appended 
"""
function ast_error(node::ASTNode, message...)
    str = ast_string(node)

    error(message..., "\nThe above error occured while processing the following AST node:\n$str")
end

ast_error(node::ASTNodeRef, message...) =
    ast_error(node[], message...)

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

ast_error(node::WrapperTree, message...) =
    ast_error(get_original(node)[], message...)

ast_string(sym::Symbol) = ":$sym"
ast_string(str::String) = "\"$str\""
ast_string(node::ASTNode) = string(node)

"""
    get_param_names(f::Expr) -> Vector{Symbol}

Return a vector of symbols consisting of the parameter names of the function definition expression `f`.
"""
function get_param_names(f::Expr)::Vector{Symbol}
    @debug_assert f.head == :function

    params = Vector{Symbol}()
    fdecl = f.args[1]

    for param_decl in fdecl.args[2:end]
        @debug_assert param_decl isa Symbol || (param_decl isa Expr && param_decl.head in [:(::), :decl])

        if param_decl isa Symbol
            push!(params, param_decl)
        elseif param_decl.head == :(::)
            push!(params, param_decl.args[1])
        elseif param_decl.head == :decl
            push!(params, param_decl.args[1].value)
        end
    end

    params
end

"""
    get_param(f::Expr, name::Symbol) -> Union{Expr,Symbol,Missing}

Return the declaration node of parameter named `name` from function definition expression `f`.

# Returns
- `Expr`: The expression node, if the declaration is a complex decl (e.g. `function f(a::Int) end`). This also includes Transpiler-specific `Expr(:decl, ...)` nodes.
- `Symbol`: The symbol node, if the declaration simply consists of the param's name (e.g. `function f(a) end`)
- `Missing`: `missing`, if a parameter named `name` couldn't be found in `f`
"""
function get_param(f::Expr, name::Symbol)::Union{Expr,Symbol,Missing}
    @debug_assert f.head == :function

    fdecl = f.args[1]

    for param_decl in fdecl.args[2:end]
        pname = missing

        if param_decl isa Symbol
            pname = param_decl
        elseif param_decl.head == :(::)
            pname = param_decl.args[1]
        elseif param_decl.head == :decl
            pname = param_decl.args[1].value
        end

        @debug_assert !ismissing(pname)

        if pname == name
            return param_decl
        end
    end

    return missing
end

"""
    resolve_module_chain(expr::Expr, mod::Module) -> Any

Returns whatever the module chain expression `expr` points to, starting from module `mod`.

Module chain expressions are [`Expr`](@ref)s like `ModA.ModB.my_func`.
"""
function resolve_module_chain(expr::Expr, mod::Module)
    @debug_assert expr.head == :(.)
    @debug_assert length(expr.args) == 2
    @debug_assert expr.args[2] isa QuoteNode

    if expr.args[1] isa Symbol
        is_def = isdefined(mod, expr.args[1])
        @debug_assert is_def || expr.args[1] == :JuliaGLM

        base_mod = is_def ? getfield(mod, expr.args[1]) : JuliaGLM
    else
        base_mod = resolve_module_chain(expr.args[1], mod)
    end

    @debug_assert base_mod isa Module
    @debug_assert isdefined(base_mod, expr.args[2].value)

    getfield(base_mod, expr.args[2].value)
end

"""
    replace_decls(f::Expr) -> Expr

Return a new function with all Transpiler-specific `Expr(:decl, ...)` declarations replaced with their valid Julia counterpart.
"""
function replace_decls(f::Expr)
    @debug_assert f.head == :function

    replace_decls_traverse!(f)

    f
end

function replace_decls_traverse!(node::ASTNode)
    if node isa Expr
        for (i, arg) in enumerate(node.args)
            if arg isa Expr && arg.head == :decl
                name = arg.args[1].value
                type = arg.args[2]

                node.args[i] = :($name::$type)
                continue
            end

            replace_decls_traverse!(arg)
        end
    end
end

"""
    try_type_from_ast(ex::Union{Expr,Symbol}, mod::Module) -> Union{DataType, Nothing}

Try to return the [`DataType`](@ref) pointed to by `ex` in module `mod`. If it doesn't point to anything, or it points to a non-DataType object, [`nothing`](@ref) is returned.

# Arguments
- `ex::Union{Symbol,Expr}`: If `ex` is a [`Symbol`](@ref), it is simply resolved in `mod`. If it's an [`Expr`](@ref) of a module chain expression (see [`resolve_module_chain`](@ref)), that path is traversed starting from `mod` to find the result.
- `mod::Module`: The base [`Module`](@ref) to start the look-up from.

# Returns
- `DataType`: The type if `ex` points to an object that is defined and `isa DataType`
- `Nothing`: If `ex` doesn't point to a defined object starting from `mod`, or what it points to is not a `DataType`
"""
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

    @debug_assert !isempty(length(location_chain)) && all(s -> s isa Symbol, location_chain)

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

"""
    type_from_ast(node::Union{Expr,Symbol}, mod::Module) -> DataType

Same as [`try_type_from_ast`](@ref), but throws an [`ast_error`](@ref) instead of returning [`nothing`](@ref).
"""
function type_from_ast(node::Union{Expr,Symbol}, mod::Module)::DataType
    result = try_type_from_ast(node, mod)

    if isnothing(result)
        ast_error(node, "Couldn't resolve type from AST node in module $mod")
    end

    result
end
