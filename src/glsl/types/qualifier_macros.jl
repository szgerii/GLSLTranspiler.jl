#=
==================
Custom declaration Expr format:
==================
head = :(decl)
args:
  [1]::Union{QuoteNode,Symbol} - the target variable's name 
  [2]::Union{DataType,Missing} =: T - the Julia type of the variable
  [3]::Union{QuoteNode,Symbol,Missing} - the scope of the declaration (:global, :local, :param)
  [4]::Vector{Qualifier} - a list of qualifiers for the declaration
  [5]::Union{T,Nothing} - the initially assigned value of the declaration
=#

"""
    decorate(mod::Module, qualifier::Qualifier, rest::Union{Expr,Symbol}) -> Expr

Helper function for [`gen_qualifier_macros`](@ref).
Expands a qualifier macro into a custom :decl [`Expr`](@ref)-format. 
"""
function decorate(mod::Module, qualifier::Qualifier, rest::Union{Expr,Symbol})
    rest = macroexpand(mod, rest; recursive=false)
    rhs = nothing

    if rest isa Symbol || (rest isa Expr && rest.head in [:(::), :(=), :local, :global])
        decl_type = missing
        decl_val  = nothing

        # unwrap Julia declaration
        if rest isa Expr && rest.head in [:local, :global]
            decl_type = rest.head
            rest = rest.args[1]
        end

        # unwrap assignment lhs
        if rest isa Expr && rest.head == :(=)
            rhs = rest.args[2]
            rest = rest.args[1]

            decl_val = QuoteNode(rhs)
        end

        name = rest isa Symbol ? rest : rest.args[1]
        @debug_assert name isa Symbol

        if rest isa Symbol
            type = missing
        else
            type = rest.args[2]

            if type isa QuoteNode
                type = type.value
            end

            if type isa Symbol
                @debug_assert isdefined(mod, type)
                type = getfield(mod, type)
            end
        end

        return Expr(:decl, QuoteNode(name), type, decl_type isa Symbol ? QuoteNode(decl_type) : decl_type, Qualifier[qualifier], decl_val)
    elseif rest isa Expr && rest.head == :decl
        @debug_assert rest.args[4] isa Vector

        push!(rest.args[4], qualifier)
        return rest
    end

    error("Unexpected Expr encountered during variable unwrapping: $rest")
end

# ================================================
# Generate macros for the qualifiers defined above
# ================================================

"""
    gen_qualifier_macros()

Actually defines the Qualifier macros based on the Qualifier abstract type.
"""
function gen_qualifier_macros()
    type_queue = subtypes(Qualifier)
    while !isempty(type_queue)
        type = popfirst!(type_queue)

        if type <: LayoutQualifier || type <: BufferQualifier
            continue
        end

        if !isconcretetype(type)
            type_queue = vcat(type_queue, subtypes(type))
            continue
        end

        @debug_assert has_empty_ctor(type)

        macro_sym = split(string(nameof(type)), "Qualifier"; keepempty=false)[1] |> lowercase |> Symbol
        
        # declaration chain unwrapping macro-variant 
        @eval @__MODULE__() macro $macro_sym(rest)
            decorate(__module__, $type(), rest)
        end

        # independent macro-variant (used with interface blocks for example)
        # @eval @__MODULE__() macro $macro_sym()
        #     $type()
        # end

        export_expr = Expr(:export, Symbol("@", macro_sym))
        @__MODULE__().eval(export_expr)
    end
end
gen_qualifier_macros()

# =====================
# Special @layout macro
# =====================

export @layout

macro layout(args...)
    syms = Symbol[]
    assignments = Expr[]

    if length(args) == 0
        error("Invalid @layout usage: @layout called outside of a declaration chain, or interface block declaration")
    end

    if length(args) == 1
        error(
            "Invalid @layout usage: empty argument list in a @layout call"
        )
    end

    # used for error messages
    layout_str = "@layout $(join(args, ' '))"

    for i in 1:lastindex(args)-1
        if args[i] isa QuoteNode
            args[i] = args[i].value
        end

        is_sym = args[i] isa Symbol
        is_assignment = !is_sym && args[i] isa Expr && args[i].head == :(=)

        if !is_sym && !is_assignment
            error(
                "Invalid @layout usage: non-Symbol, non-assignment argument in non-final position in the following @layout call:\n",
                layout_str, "\n",
                "Non-final arguments must be all Symbols (or QuoteNodes wrapping Symbols), or assignments, specifying the sub-qualifiers and values of the layout qualifier."
            )
        end

        if is_sym
            push!(syms, args[i])
        else
            push!(assignments, args[i])
        end
    end

    options = LayoutQualifierOption[]

    for sym in syms
        push!(options, LayoutQualifierOption(sym))
    end

    for assignment in assignments
        if assignment.args[1] isa QuoteNode
            assignment.args[1] = assignment.args[1].value
        end

        if !(assignment.args[1] isa Symbol)
            error(
                "Invalid @layout usage: non-Symbol value found on the left-hand side of an assignment in the following @layout call:\n",
                layout_str, "\n",
                "Assignment left-hand sides must either be a Symbol, or a QuoteNode wrapping a Symbol."
            )
        end

        if !(assignment.args[2] isa Integer)
            error(
                "Invalid @layout usage: expected integer literal value value on the right-hand side of an assignment in the following @layout call, got $(typeof(assignment.args[2])) instead:\n",
                layout_str, "\n",
                "Assignment right-hand sides must be integer literals."
            )
        end

        push!(options, LayoutQualifierOption(assignment.args[1], assignment.args[2]))
    end

    qualifier = LayoutQualifier(options)

    decorate(__module__, qualifier, args[end])
end

# ==============================
# Compute shader specific macros
# ==============================

export @local_size

macro local_size(x::Int, y::Int=1, z::Int=1)
    @debug_assert x > 0 && y > 0 && z > 0 "Cannot set local size of compute shader to a non-positive value"

    return Expr(:local_size, x, y, z)
end
