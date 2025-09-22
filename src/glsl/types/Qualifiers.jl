using InteractiveUtils

@exported abstract type Qualifier end

# Storage Qualifiers

@exported abstract type StorageQualifier <: Qualifier end

@exported struct ConstantQualifier <: StorageQualifier end
@exported struct InQualifier <: StorageQualifier end
@exported struct OutQualifier <: StorageQualifier end
@exported struct UniformQualifier <: StorageQualifier end
@exported struct SharedQualifier <: StorageQualifier end

# Interpolation Qualifiers
# These are technically storage qualifiers too

@exported abstract type InterpolationQualifier <: Qualifier end

@exported struct FlatQualifier <: InterpolationQualifier end
@exported struct NoPerspectiveQualifier <: InterpolationQualifier end
@exported struct SmoothQualifier <: InterpolationQualifier end

# Layout Qualifiers

export LAYOUT_QUALIFIER_OPTIONS

const LAYOUT_QUALIFIER_OPTIONS = [
    (:location, true),
    (:index, true),
    (:component, true),
    (:binding, true),
    (:offset, true),
    (:xfb_buffer, true),
    (:xfb_offset, true),
    (:xfb_stride, true),
    (:vertices, true),

    # Image Format Qualifiers

    # Floating point
    (:rgba32f, false),
    (:rgba16f, false),
    (:rg32f, false),
    (:rg16f, false),
    (:r11f_g11f_b10f, false),
    (:r32f, false),
    (:r16f, false),
    (:rgba16, false),
    (:rgb10_a2, false),
    (:rgba8, false),
    (:rg16, false),
    (:rg8, false),
    (:r16, false),
    (:r8, false),
    (:rgba16_snorm, false),
    (:rgba8_snorm, false),
    (:rg16_snorm, false),
    (:rg8_snorm, false),
    (:r16_snorm, false),
    (:r8_snorm, false),
    # Signed Integer
    (:rgba32i, false),
    (:rgba16i, false),
    (:rgba8i, false),
    (:rg32i, false),
    (:rg16i, false),
    (:rg8i, false),
    (:r32i, false),
    (:r16i, false),
    (:r8i, false),
    # Unsigned Integer
    (:rgba32ui, false),
    (:rgba16ui, false),
    (:rgb10_a2ui, false),
    (:rgba8ui, false),
    (:rg32ui, false),
    (:rg16ui, false),
    (:rg8ui, false),
    (:r32ui, false),
    (:r16ui, false),
    (:r8ui, false),

    # Memory Layout
    (:packed, false),
    (:shared, false),
    (:std140, false),
    (:std430, false),

    # Geometry Shader Primitives
    (:max_vertices, true),
    (:points, false),
    (:lines, false),
    (:lines_adjacency, false),
    (:triangles, false),
    (:triangles_adjacency, false),
    (:line_strip, false),
    (:triangle_strip, false),

    # Fragment Shader Coordinate Origin
    (:origin_upper_left, false),
    (:pixel_center_integer, false),

    # Early Fragment Tests
    (:early_fragment_tests, false),

    # Tesselation Evaluation Options
    # TODO
]

@exported struct LayoutQualifierOption
    name::Symbol
    value::Union{Integer,Nothing}

    function LayoutQualifierOption(name::Symbol, value::Union{Integer,Missing}=missing)
        option = get(LAYOUT_QUALIFIER_OPTIONS, name, nothing)

        if isnothing(name)
            error("Trying to construct unknown layout qualifier option: $name")
        end

        needs_val = option[2]
        if needs_val
            if ismissing(value)
                error("Trying to construct $name layout qualifier option without a value")
            end

            return new(name, value)
        elseif !ismissing(value)
            println("WARNING: Constructing value-less layout qualifier option $name with a value")
        end

        new(name, nothing)
    end
end

@exported struct LayoutQualifier <: Qualifier
    options::Vector{LayoutQualifierOption}
end

# Precision Qualifiers
# Added for compatibility with ES at this level

@exported abstract type PrecisionQualifier <: Qualifier end

@exported struct LowPQualifier <: PrecisionQualifier end
@exported struct MediumPQualifier <: PrecisionQualifier end
@exported struct HighPQualifier <: PrecisionQualifier end

# Memory Qualifiers

@exported abstract type MemoryQualifier <: Qualifier end

@exported struct CoherentQualifier <: MemoryQualifier end
@exported struct VolatileQualifier <: MemoryQualifier end
@exported struct RestrictQualifier <: MemoryQualifier end
@exported struct ReadOnlyQualifier <: MemoryQualifier end
@exported struct WriteOnlyQualifier <: MemoryQualifier end

# Misc Qualifiers

@exported struct InvariantQualifier <: Qualifier end
@exported struct CentroidQualifier <: Qualifier end
@exported struct SampleQualifier <: Qualifier end

"""
    decorate(mod::Module, qualifier::Qualifier, rest::Union{Expr,Symbol}) -> Expr

Helper function for [`gen_qualifier_macros`](@ref).
Expands a qualifier macro into a custom :decl [`Expr`](@ref)-format. 
"""
function decorate(mod::Module, qualifier::Qualifier, rest::Union{Expr,Symbol})
    rest = macroexpand(mod, rest; recursive=false)

    if rest isa Symbol || (rest isa Expr && rest.head == :(::))
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

        return Expr(:decl, QuoteNode(name), type, missing, Qualifier[qualifier])
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

        if type <: LayoutQualifier
            continue
        end

        if !isconcretetype(type)
            type_queue = vcat(type_queue, subtypes(type))
            continue
        end

        @debug_assert has_empty_ctor(type)

        macro_sym = split(string(nameof(type)), "Qualifier"; keepempty=false)[1] |> lowercase |> Symbol
        @eval @__MODULE__() macro $macro_sym(rest)
            decorate(__module__, $type(), rest)
        end

        export_expr = Expr(:export, Symbol("@", macro_sym))
        @__MODULE__().eval(export_expr)
    end
end
gen_qualifier_macros()

# ================
# Helper Functions
# ================

const QUALIFIER_PRECEDENCE = [
    InvariantQualifier, InterpolationQualifier, LayoutQualifier,
    # These extra Union types ensure that centroid and sample immediately precede in/out qualifiers (for pre-4.2 compatibility) 
    Union{CentroidQualifier,SampleQualifier}, Union{InQualifier,OutQualifier},
    StorageQualifier, PrecisionQualifier
]

export sort_qualifiers

"""
    sort_qualifiers(qualifiers::Vector{<:Qualifier}) -> Vector{<:Qualifier}

Sorts a list of qualifiers based on their declaration order according to the GLSL spec.
"""
function sort_qualifiers(qualifiers::Vector{<:Qualifier})
    result = sort(qualifiers, by=q -> begin
        idx = findfirst(T -> q isa T, QUALIFIER_PRECEDENCE)
        !isnothing(idx) ? idx : length(qualifiers) + 1
    end)

    result
end
