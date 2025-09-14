# ============================
# Generic types for signatures
# ============================

const GLCtx = GLSLPipelineContext

const GenFType = Union{ASTVecNF,ASTFloat32}
const GenDType = Union{ASTVecND,ASTFloat64}
const GenIType = Union{ASTVecNI,ASTInt32}
const GenUType = Union{ASTVecNU,ASTUInt32}
const GenBType = Union{ASTVecNB,ASTBool}

const VecTypes = Union{ASTVecNF,ASTVecND,ASTVecNI,ASTVecNB,ASTVecNU}

const MatTypes = Union{ASTMatNxMF,ASTMatNxMD}
const SquareMatTypes = Union{ASTMat2x2F,ASTMat3x3F,ASTMat4x4F,ASTMat2x2D,ASTMat3x3D,ASTMat4x4D}

# ==================================
# Utils for fn definition generation
# ==================================

is_gen_type(::Type{T}) where T = any(GenType -> GenType <: T, [GenFType, GenDType, GenIType, GenUType, GenBType])
is_gen_type(::Type{T}) where {T<:ASTVec} = isabstracttype(T)

specialize_gen_type(::Type{<:GenFType}, ::Val{1}) = ASTFloat32
specialize_gen_type(::Type{<:GenDType}, ::Val{1}) = ASTFloat64
specialize_gen_type(::Type{<:GenIType}, ::Val{1}) = ASTInt32
specialize_gen_type(::Type{<:GenUType}, ::Val{1}) = ASTUInt32
specialize_gen_type(::Type{<:GenBType}, ::Val{1}) = ASTBool

for n in 2:4
    for typ in ["F", "D", "I", "U", "B"]
        vec_sym = Symbol("ASTVec", n, typ)
        gen_type_sym = Symbol("Gen", typ, "Type")
        @eval specialize_gen_type(::Type{<:$gen_type_sym}, ::Val{$n}) = $vec_sym
    end
end

function specialize_union(::Type{T}, n::Int) where T
    @assert T isa Union "Trying to specialize Union of gen types on a non-Union type"

    sub_types = Base.uniontypes(T)

    Union{map(gen_type -> specialize_gen_type(gen_type, Val(n)), sub_types)...}
end

# Utils for defining signatures in the dictionary

fill_tuple(x, n::Int) = ntuple(_ -> x, n)

repeat_signature(syms::Vector{Symbol}, sig) =
    [fsym => sig for fsym in syms]

# =======================================
# Define the built-in function signatures
# =======================================

# GLSL built-in functions with format:
# fn_name => ([param1, param2, ...,] ret_type)
const GLSL_BUILTIN_FNS = Dict(
    # Angle and Trigonometry Functions (8.1)
    repeat_signature([
            :radians, :degrees,
            :sin, :cos, :tan,
            :asin, :acos,
            :sinh, :cosh, :tanh,
            :asinh, :acosh, :atanh
        ], (GenFType, GenFType))...,
    :atan => [
        (GenFType, GenFType),
        (GenFType, GenFType, GenFType)
    ],

    # Exponential Functions (8.2)
    :pow => (GenFType, GenFType, GenFType),
    repeat_signature([:exp, :log, :exp2, :log2], (GenFType, GenFType))...,
    :sqrt => fill_tuple(Union{GenFType,GenDType}, 2),
    :inversesqrt => fill_tuple(Union{GenFType,GenDType}, 2),

    # Common Functions (8.3)
    repeat_signature([
            :abs, :sign,
            :floor, :trunc, :ceil, :fract,
            :round, :roundEven,
        ], fill_tuple(Union{GenFType,GenDType}, 2))...,
    :mod => [
        fill_tuple(Union{GenFType,GenDType}, 3),
        (GenFType, ASTFloat32, GenFType),
        (GenDType, ASTFloat64, GenDType)
    ],
    :modf => (Union{GenFType,GenDType}, Ref{Union{GenFType,GenDType}}, Union{GenFType,GenDType}),
    repeat_signature([:min, :max], [
        fill_tuple(Union{GenFType,GenDType,GenIType,GenUType}, 3),
        (GenFType, ASTFloat32, GenFType),
        (GenDType, ASTFloat64, GenDType),
        (GenIType, ASTInt32, GenIType),
        (GenUType, ASTUInt32, GenUType),
    ])...,
    :clamp => [
        fill_tuple(Union{GenFType,GenDType,GenIType,GenUType}, 4),
        (GenFType, ASTFloat32, ASTFloat32, GenFType),
        (GenDType, ASTFloat64, ASTFloat64, GenDType),
        (GenIType, ASTInt32, ASTInt32, GenIType),
        (GenUType, ASTUInt32, ASTUInt32, GenUType),
    ],
    :mix => [
        fill_tuple(Union{GenFType,GenDType}, 4),
        (GenFType, GenFType, ASTFloat32, GenFType),
        (GenDType, GenDType, ASTFloat64, GenDType),
        (fill_tuple(Union{GenFType,GenDType,GenIType,GenUType,GenBType}, 2)..., GenBType, Union{GenFType,GenDType,GenIType,GenUType,GenBType})
    ],
    :step => [
        fill_tuple(Union{GenFType,GenDType}, 3),
        (ASTFloat32, GenFType, GenFType),
        (ASTFloat64, GenDType, GenDType),
    ],
    :smoothstep => [
        fill_tuple(Union{GenFType,GenDType}, 4),
        (ASTFloat32, ASTFloat32, GenFType, GenFType),
        (ASTFloat64, ASTFloat64, GenDType, GenDType),
    ],
    :isnan => (Union{GenFType,GenDType}, GenBType),
    :isinf => (Union{GenFType,GenDType}, GenBType),
    :floatBitsToInt => (GenFType, GenIType),
    :floatBitsToUint => (GenFType, GenUType),
    :intBitsToFloat => (GenIType, GenFType),
    :uintBitsToFloat => (GenUType, GenFType),
    :fma => fill_tuple(Union{GenFType,GenDType}, 4),
    :frexp => (Union{GenFType,GenDType}, Ref{GenIType}, Union{GenFType,GenDType}),
    :ldexp => (Union{GenFType,GenDType}, GenIType, Union{GenFType,GenDType}),

    # Floating-Point Pack and Unpack (8.4)
    :packUnorm2x16 => (ASTVec2F, ASTUInt32),
    :packSnorm2x16 => (ASTVec2F, ASTUInt32),
    :packUnorm4x8 => (ASTVec4F, ASTUInt32),
    :packSnorm4x8 => (ASTVec4F, ASTUInt32),
    :unpackUnorm2x16 => (ASTUInt32, ASTVec2F),
    :unpackSnorm2x16 => (ASTUInt32, ASTVec2F),
    :unpackUnorm4x8 => (ASTUInt32, ASTVec4F),
    :unpackSnorm4x8 => (ASTUInt32, ASTVec4F),
    :packHalf2x16 => (ASTVec2F, ASTUInt32),
    :unpackHalf2x16 => (ASTUInt32, ASTVec2F),
    :packDouble2x32 => (ASTVec2U, ASTFloat64),
    :unpackDouble2x32 => (ASTFloat64, ASTVec2U),

    # Geometric Functions (8.5)
    :length => [
        (GenFType, ASTFloat32),
        (GenDType, ASTFloat64)
    ],
    :distance => [
        (GenFType, GenFType, ASTFloat32),
        (GenDType, GenDType, ASTFloat64),
    ],
    :dot => [
        (GenFType, GenFType, ASTFloat32),
        (GenDType, GenDType, ASTFloat64)
    ],
    :cross => [
        fill_tuple(ASTVec3F, 3),
        fill_tuple(ASTVec3D, 3),
    ],
    :normalize => fill_tuple(Union{GenFType,GenDType}, 2),
    :frtransform => (ASTVec4F,),
    :faceforward => fill_tuple(Union{GenFType,GenDType}, 4),
    :reflect => fill_tuple(Union{GenFType,GenDType}, 3),
    :refract => [
        (GenFType, GenFType, ASTFloat32, GenFType),
        (GenDType, GenDType, ASTFloat64, GenDType)
    ],

    # Matrix Functions (8.6)
    # These are defined separately below
    # Adding support for generic matrix types like I did with GenTypes felt overkill for these 5 fns

    # Vector Relational Functions (8.7)
    repeat_signature(
        [:lessThan, :lessThanEqual, :greaterThan, :greaterThanEqual],
        (fill_tuple(Union{ASTVecNF,ASTVecNI,ASTVecNU}, 2)..., ASTVecNB)
    )...,
    :equal => (fill_tuple(Union{ASTVecNF,ASTVecNI,ASTVecNU,ASTVecNB}, 2)..., ASTVecNB),
    :notEqual => (fill_tuple(Union{ASTVecNF,ASTVecNI,ASTVecNU,ASTVecNB}, 2)..., ASTVecNB),
    :any => (ASTVecNB, ASTBool),
    :all => (ASTVecNB, ASTBool),
    :not => (ASTVecNB, ASTVecNB),

    # Integer Functions (8.8)
    :uaddCarry => (GenUType, GenUType, Ref{GenUType}, GenUType),
    :usubBorrow => (GenUType, GenUType, Ref{GenUType}, GenUType),
    :umulExtended => (GenUType, GenUType, Ref{GenUType}, Ref{GenUType}, ASTVoid),
    :imulExtended => (GenIType, GenIType, Ref{GenIType}, Ref{GenIType}, ASTVoid),
    :bitfieldExtract => [
        (GenIType, ASTInt32, ASTInt32, GenIType),
        (GenUType, ASTInt32, ASTInt32, GenUType)
    ],
    :bitfieldInsert => [
        (GenIType, GenIType, ASTInt32, ASTInt32, GenIType),
        (GenUType, GenUType, ASTUInt32, ASTUInt32, GenUType),
    ],
    :bitfieldReverse => fill_tuple(Union{GenIType,GenUType}, 2),
    :bitCount => (Union{GenIType,GenUType}, GenIType),
    :findLSB => (Union{GenIType,GenUType}, GenIType),
    :findMSB => (Union{GenIType,GenUType}, GenIType),

    # Texture Functions (8.9)
    # TODO (samplers)

    # Atomic Counter Functions (8.10)
    # TODO (atomic_uint)

    # Atomic Memory Functions (8.11)
    repeat_signature([
            :atomicAdd, :atomicMin, :atomicMax,
            :atomicAnd, :atomicOr, :atomicXor,
            :atomicExchange
        ], [
            (Ref{ASTUInt32}, ASTUInt32, ASTUInt32),
            (Ref{ASTInt32}, ASTInt32, ASTInt32),
        ])...,
    :atomicCompSwap => [
        (Ref{ASTUInt32}, ASTUInt32, ASTUInt32, ASTUInt32,),
        (Ref{ASTInt32}, ASTInt32, ASTInt32, ASTInt32,),
    ],

    # Image Functions (8.12)
    # TODO

    # Geometry Shader Functions (8.13)
    :EmitStreamVertex => (ASTInt32, ASTVoid),
    :EndStreamPrimitive => (ASTInt32, ASTVoid),
    :EmitVertex => (ASTVoid,),
    :EndPrimitive => (ASTVoid,),

    # Fragment Processing Functions (8.14)
    repeat_signature([
            :dFdx, :dFdxFine, :dFdxCoarse,
            :dFdy, :dFdyFine, :dFdyCoarse,
            :fwidth, :fwidthFine, :fwidthCoarse,
        ], (GenFType, GenFType))...,
    :interpolateAtCentroid => (GenFType, GenFType),
    :interpolateAtSample => (GenFType, ASTInt32, GenFType),
    :interpolateAtOffset => (GenFType, ASTVec2F, GenFType),

    # Noise Functions (8.15)
    :noise1 => (GenFType, ASTFloat32),
    :noise2 => (GenFType, ASTVec2F),
    :noise3 => (GenFType, ASTVec3F),
    :noise4 => (GenFType, ASTVec4F),

    # Shader Invocation Control Functions (8.16)
    :barrier => (ASTVoid,),

    # Shader Memory Control Functions (8.17)
    repeat_signature([
            :memoryBarrier,
            :memoryBarrierAtomicCounter,
            :memoryBarrierBuffer,
            :memoryBarrierShared,
            :memoryBarrierImage,
            :groupMemoryBarrier,
        ], (ASTVoid,))...,

    # Subpass-Input Functions (8.18)
    # TODO

    # Shader Invocation Group Functions (8.19)
    repeat_signature([:anyInvocation, :allInvocations, :allInvocationsEqual], (ASTBool, ASTBool))...,
)

# Matrix Functions (8.6)

TypeInference.builtin_fn_ret_type(::GLCtx, ::Val{:matrixCompMult}, ::Type{M}, ::Type{M}) where {M<:MatTypes} = M

function TypeInference.builtin_fn_ret_type(::GLCtx, ::Val{:outerProduct}, ::Type{V1}, ::Type{V2}) where {V1<:VecTypes,V2<:VecTypes}
    el_type = eltype(V1)

    if !(el_type <: Union{Float32,Float64}) || eltype(V2) != el_type
        return nothing
    end

    v1_el_count, v2_el_count = elcount(V1), elcount(V2)

    get_ast_mat_type(el_type, v2_el_count, v1_el_count)
end

TypeInference.builtin_fn_ret_type(::GLCtx, ::Val{:transpose}, ::Type{M}) where {M<:MatTypes} =
    get_ast_mat_type(eltype(M), reverse(size(to_ast(M)))...)

TypeInference.builtin_fn_ret_type(::GLCtx, ::Val{:determinant}, ::Type{M}) where {M<:SquareMatTypes} = ASTFloat32
TypeInference.builtin_fn_ret_type(::GLCtx, ::Val{:inverse}, ::Type{M}) where {M<:SquareMatTypes} = M

# ==============================================
# Generate methods based on the above dictionary
# ==============================================

# TODO
# perf could possibly be improved here by grouping all the definitions into a single quote block and only @eval-ing that once
# the resulting definitions could also be saved to a file to improve precompile time (maybe invalidate based on changes to the dictionary?)

function define_builtin(fsym::Symbol, params_sig, ret_val)
    @assert ret_val isa Symbol || isconcretetype(ret_val)

    fn_def = :(TypeInference.builtin_fn_ret_type(::GLCtx, ::Val{$(QuoteNode(fsym))}, $(params_sig...)) = $ret_val)

    @eval $fn_def
    fn_def
end

function define_builtin(fsym::Symbol, params_sig, type_vars_sig, ret_val)
    @assert ret_val isa Symbol || isconcretetype(ret_val)

    fn_def = :(TypeInference.builtin_fn_ret_type(::GLCtx, ::Val{$(QuoteNode(fsym))}, $(params_sig...)) where {$(type_vars_sig...)} = $ret_val)

    @eval $fn_def
    fn_def
end

genned = Expr(:block)

for (fsym, sigs) in GLSL_BUILTIN_FNS
    if !(sigs isa Vector)
        sigs = [sigs]
    end

    for sig in sigs
        @assert sig isa Tuple && length(sig) > 0 "Invalid function signature for GLSL built-in function $fsym"

        gen_type_params = []
        for param in sig
            if !(param in gen_type_params) && (is_gen_type(param) || (param isa Union && any(is_gen_type, Base.uniontypes(param))))
                push!(gen_type_params, param)
            end
        end

        current_type_id = 1
        type_vars = Dict()
        params_sig = []

        for param_type in sig[1:end-1]
            is_ref = param_type <: Ref

            if is_ref
                param_type = param_type.parameters[1]
            end

            @assert param_type <: ASTType "Type not supported by the type inference stage found in signature for built-in GLSL function '$fsym': $param_type"

            if !(param_type isa Union) && !is_gen_type(param_type)
                t_sig = is_ref ? :(::Type{<:Ref{$param_type}}) : :(::Type{$param_type})
                push!(params_sig, t_sig)
                continue
            end

            tv = get(type_vars, param_type, nothing)

            if isnothing(tv)
                tv = Symbol(:T, current_type_id)
                current_type_id += 1

                type_vars[param_type] = tv
            end

            t_sig = is_ref ? :(::Type{<:Ref{$tv}}) : :(::Type{$tv})
            push!(params_sig, t_sig)
        end

        ret_val = get(type_vars, sig[end], sig[end])

        if length(type_vars) == 0
            push!(genned.args, define_builtin(fsym, params_sig, ret_val))
        elseif length(gen_type_params) >= 2
            for n in 1:4
                type_vars_sig = []
                for (type, type_var) in type_vars
                    @assert type isa Union

                    spec_type = specialize_union(type, n)
                    push!(type_vars_sig, :($type_var <: $spec_type))
                end

                spec_ret_val = (ret_val isa Type && is_gen_type(ret_val)) ? specialize_gen_type(ret_val, Val(n)) : ret_val

                push!(genned.args, define_builtin(fsym, params_sig, type_vars_sig, spec_ret_val))
            end
        else
            type_vars_sig = [:($type_var <: $type) for (type, type_var) in type_vars]

            push!(genned.args, define_builtin(fsym, params_sig, type_vars_sig, ret_val))
        end
    end
end

# This can be used to check output

#Base.remove_linenums!(genned)
#open("builtin_gen.jl", "w") do io
#    print(io, genned)
#end
