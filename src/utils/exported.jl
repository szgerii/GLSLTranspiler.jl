export @exported

macro exported(def::Expr)
    @assert def.head in [:struct, :abstract] "The @exported macro can only be used on struct definitions and abstract types"

    Base.remove_linenums!(def)

    if def.head == :abstract
        name = def.args[1]
    elseif def.args[2] isa Symbol
        name = def.args[2]
    else
        name_def = def.args[2]

        # unwrap inheritance
        if name_def isa Expr && name_def.head == :(<:)
            name_def = name_def.args[1]
        end

        # unwrap type parameters
        if name_def isa Expr && name_def.head == :curly
            name_def = name_def.args[1]
        end

        name = name_def
    end

    @assert name isa Symbol

    quote
        export $name
        $(esc(def))
    end
end
