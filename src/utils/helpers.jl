export @exported, @debug_assert

"""
    @exported def::Expr -> Expr

Defines and exports the type described by `def`. `def` must be an abstract type definition or a struct definition. 

The macro takes into account subtyping and parametric types.
"""
macro exported(def::Expr)
    @assert def.head in [:struct, :abstract] "The @exported macro can only be used on struct definitions and abstract types"

    Base.remove_linenums!(def)

    if def.head == :abstract
        name = def.args[1]

        if name isa Expr && name.head == :(<:)
            name = name.args[1]
        end
    elseif def.args[2] isa Symbol
        name = def.args[2]
    else
        name = def.args[2]

        # unwrap inheritance
        if name isa Expr && name.head == :(<:)
            name = name.args[1]
        end

        # unwrap type parameters
        if name isa Expr && name.head == :curly
            name = name.args[1]
        end
    end

    @assert name isa Symbol "The resolved name is not a Symbol (name = $name)"

    quote
        export $name
        $(esc(def))
    end
end

"""
    @debug_assert ex::Expr msg::Any=missing

Inserts an assertion for `ex` if the `TRANSPILER_DEBUG` environment variable is set, with optional message argument `msg`.
"""
macro debug_assert(ex, msg=missing)
    if haskey(ENV, "TRANSPILER_DEBUG")
        if ismissing(msg)
            return :(@assert $(esc(ex)) $(string(ex)))
        else
            return :(@assert $(esc(ex)) $(esc(msg)))
        end
    end

    return :(nothing)
end

