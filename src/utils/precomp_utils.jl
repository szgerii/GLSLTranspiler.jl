using InteractiveUtils

export precomp_subtypes, precomp_union_types

"""
    precomp_subtypes(supertype::Type, fn, signature::Tuple, as_type_param::Bool = true)

Precompiles the function `fn` with type signature `signature`, replacing the [`missing`](@ref) elements inside `signature` with every concrete subtype of `supertype`.

Handles Union unrolling and multiple levels of subtypes as well.

`as_type_param` (`true` by default) controls whether the subtypes are treated in the signature as type parameters (`::Type{T}`), or as parameter types (`_::T`). 
"""
function precomp_subtypes(supertype::Type, fn, signature::Tuple, as_type_param::Bool=true)
    @assert isabstracttype(supertype)

    for T in subtypes(supertype)
        if T isa Union
            precomp_union_types(T, fn, signature, as_type_param)
        elseif isabstracttype(T)
            precomp_subtypes(T, fn, signature, as_type_param)
        end

        if !isconcretetype(T)
            continue
        end

        target_type = as_type_param ? Type{T} : T
        concrete_signature = replace(signature, missing => target_type)
        precompile(fn, concrete_signature)
    end
end

"""
    precomp_union_types(union_type::Type, fn, signature::Tuple, as_type_param::Bool = false)

Precompiles the function `fn` with type signature `signature`, replacing the [`missing`](@ref) elements inside `signature` with every possible concrete type derived from `union_type`.

Handles Union unrolling and multiple levels of subtypes as well.

`as_type_param` (`false` by default) controls whether the concrete types are treated in the signature as type parameters (`::Type{T}`), or as parameter types (`_::T`). 

"""
function precomp_union_types(union_type::Type, fn, signature::Tuple, as_type_param::Bool=false)
    @assert union_type isa Union

    u_types = Base.uniontypes(union_type)

    for u_type in u_types
        if u_type isa Union
            precomp_union_types(u_type, fn, signature, as_type_param)
        elseif isabstracttype(u_type)
            precomp_subtypes(u_type, fn, signature, as_type_param)
        elseif isconcretetype(u_type)
            target_type = as_type_param ? Type{u_type} : u_type
            concrete_signature = replace(signature, missing => target_type)
            precompile(fn, concrete_signature)
        end
    end
end
