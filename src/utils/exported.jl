export @exported

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

        name = name
    end

    @assert name isa Symbol "The resolved name is not a Symbol (name = $name)"

    quote
        export $name
        $(esc(def))
    end
end
