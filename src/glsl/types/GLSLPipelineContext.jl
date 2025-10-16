export GLSLPipelineContext

const GLSLVarList = Vector{Tuple{Symbol,DataType}}

"""
    GLSLPipelineContext(env_syms, def_transform, helpers, helper_sigs, in_helper) <: PipelineContext

Stores context information for a GLSL pipeline transpilation.

# Fields
- `env_syms::Vector{Tuple{Symbol,DataType}}`: Stores the list of GLSL built-in variables and their types. It can also be expanded dynamically with other fixed type, fixed name global symbols during early pipeline stages.
- `def_transform::Union{Function,Nothing,Missing}`: The transformation function applied to the fn def [`Expr`](@ref) before saving it during pipeline execution (defaults to [`remove_env_sym_decls`](@ref))
- `helpers::Vector{Tuple{Expr,Any}}`: List for storing helper function pipeline outputs
- `helper_sigs::Dict{Tuple{Symbol,Tuple},DataType}`: Dictionary for looking up helper fn return types based on their name and signature
- `in_helper::Bool`: Indicates whether the current stage is being ran on a helper function or the main function
- `interface_decls::Vector{GLSLDeclaration}`: Temporary storage for interface-level declarations that will only be added to the generated code once the final shader code is being constructed
"""
mutable struct GLSLPipelineContext <: PipelineContext
    env_syms::GLSLVarList
    def_transform::Union{Function,Nothing,Missing}
    helpers::Vector{Tuple{Expr,Any}}
    helper_sigs::Dict{Tuple{Symbol,Tuple},DataType}
    in_helper::Bool
    interface_decls::Vector{GLSLDeclaration}
    interface_blocks::Vector{InterfaceBlock}
end

function remove_env_sym_decls!(f::Expr, pipeline_ctx::GLSLPipelineContext)
    body = f.args[2]
    env_syms = get_env_syms(pipeline_ctx)

    i = 1
    while i <= length(body.args) && body.args[i] isa Expr && body.args[i].head == :local
        sym = body.args[i].args[1]

        if sym isa Symbol && sym in env_syms
            popat!(body.args, i)
        else
            i += 1
        end
    end
end

# based on https://www.khronos.org/opengl/wiki/Built-in_Variable_(GLSL)
# TODO array vars (waiting for array support)
const GLVars = [
    # vertex shaders
    (:gl_VertexID, Int32),
    (:gl_InstanceID, Int32),
    (:gl_DrawID, Int32),
    (:gl_BaseVertex, Int32),
    (:gl_BaseInstance, Int32),
    (:gl_Position, Vec4),
    (:gl_PointSize, Float32),
    # (:gl_ClipDistance, Vector{Float32}),

    # tessellation control shaders
    (:gl_PatchVerticesIn, Int32),
    (:gl_PrimitiveID, Int32),
    (:gl_InvocationID, Int32),
    # (:gl_TessLevelOuter, Vector{Float32}),
    # (:gl_TessLevelInner, Vector{Float32}),
    (:gl_TessCoord, Vec3),

    # geometry shaders
    (:gl_Layer, Int32),
    (:gl_ViewportIndex, Int32),

    # fragment shaders
    (:gl_FragCoord, Vec4),
    (:gl_FrontFacing, Bool),
    (:gl_PointCoord, Vec2),
    (:gl_SampleID, Int32),
    (:gl_SamplePosition, Vec2),
    #(:gl_SampleMaskIn, Vector{Int32}),
    (:gl_FragDepth, Float32),
    #(:gl_SampleMask, Vector{Int32}),

    # compute shaders
    (:gl_NumWorkGroups, UVec3),
    (:gl_WorkGroupID, UVec3),
    (:gl_LocalInvocationID, UVec3),
    (:gl_GlobalInvocationID, UVec3),
    (:gl_LocalInvocationIndex, UInt32),
    (:gl_WorkGroupSize, UVec3),

    # uniforms
    # (:gl_DepthRange, )
    (:gl_NumSamples, Int32),

    # constants
    (:gl_MaxVertexAttribs, Int32),
    (:gl_MaxVertexOutputComponents, Int32),
    (:gl_MaxVertexUniformComponents, Int32),
    (:gl_MaxVertexTextureImageUnits, Int32),
    (:gl_MaxGeometryInputComponents, Int32),
    (:gl_MaxGeometryOutputComponents, Int32),
    (:gl_MaxGeometryUniformComponents, Int32),
    (:gl_MaxGeometryTextureImageUnits, Int32),
    (:gl_MaxGeometryOutputVertices, Int32),
    (:gl_MaxGeometryTotalOutputComponents, Int32),
    (:gl_MaxGeometryVaryingComponents, Int32),
    (:gl_MaxFragmentInputComponents, Int32),
    (:gl_MaxDrawBuffers, Int32),
    (:gl_MaxFragmentUniformComponents, Int32),
    (:gl_MaxTextureImageUnits1, Int32),
    (:gl_MaxClipDistances, Int32),
    (:gl_MaxCombinedTextureImageUnits, Int32),
    (:gl_MaxTessControlInputComponents, Int32),
    (:gl_MaxTessControlOutputComponents, Int32),
    (:gl_MaxTessControlUniformComponents, Int32),
    (:gl_MaxTessControlTextureImageUnits, Int32),
    (:gl_MaxTessControlTotalOutputComponents, Int32),
    (:gl_MaxTessEvaluationInputComponents, Int32),
    (:gl_MaxTessEvaluationOutputComponents, Int32),
    (:gl_MaxTessEvaluationUniformComponents, Int32),
    (:gl_MaxTessEvaluationTextureImageUnits, Int32),
    (:gl_MaxTessPatchComponents, Int32),
    (:gl_MaxPatchVertices, Int32),
    (:gl_MaxTessGenLevel, Int32),
    (:gl_MaxViewports, Int32),
    (:gl_MaxVertexUniformVectors, Int32),
    (:gl_MaxFragmentUniformVectors, Int32),
    (:gl_MaxVaryingVectors, Int32),
    (:gl_MaxVertexImageUniforms, Int32),
    (:gl_MaxVertexAtomicCounters, Int32),
    (:gl_MaxVertexAtomicCounterBuffers, Int32),
    (:gl_MaxTessControlImageUniforms, Int32),
    (:gl_MaxTessControlAtomicCounters, Int32),
    (:gl_MaxTessControlAtomicCounterBuffers, Int32),
    (:gl_MaxTessEvaluationImageUniforms, Int32),
    (:gl_MaxTessEvaluationAtomicCounters, Int32),
    (:gl_MaxTessEvaluationAtomicCounterBuffers, Int32),
    (:gl_MaxGeometryImageUniforms, Int32),
    (:gl_MaxGeometryAtomicCounters, Int32),
    (:gl_MaxGeometryAtomicCounterBuffers, Int32),
    (:gl_MaxFragmentImageUniforms, Int32),
    (:gl_MaxFragmentAtomicCounters, Int32),
    (:gl_MaxFragmentAtomicCounterBuffers, Int32),
    (:gl_MaxCombinedImageUniforms, Int32),
    (:gl_MaxCombinedAtomicCounters, Int32),
    (:gl_MaxCombinedAtomicCounterBuffers, Int32),
    (:gl_MaxImageUnits, Int32),
    (:gl_MaxCombinedImageUnitsAndFragmentOutputs, Int32),
    (:gl_MaxImageSamples, Int32),
    (:gl_MaxAtomicCounterBindings, Int32),
    (:gl_MaxAtomicCounterBufferSize, Int32),
    (:gl_MinProgramTexelOffset, Int32),
    (:gl_MaxProgramTexelOffset, Int32),
    (:gl_MaxComputeWorkGroupCount, IVec3),
    (:gl_MaxComputeWorkGroupSize, IVec3),
    (:gl_MaxComputeUniformComponents, Int32),
    (:gl_MaxComputeTextureImageUnits, Int32),
    (:gl_MaxComputeImageUniforms, Int32),
    (:gl_MaxComputeAtomicCounters, Int32),
    (:gl_MaxComputeAtomicCounterBuffers, Int32),
    (:gl_MaxTransformFeedbackBuffers, Int32),
    (:gl_MaxTransformFeedbackInterleavedComponents, Int32),
]

# The rest of the context is just implementing the general PipelineContext "interface"

CoreTypes.init_pipeline_ctx(::Type{GLSLPipelineContext}) =
    GLSLPipelineContext(deepcopy(GLVars), remove_env_sym_decls!, Vector(), Dict(), false, GLSLDeclaration[], InterfaceBlock[])

CoreTypes.get_def_transform(ctx::GLSLPipelineContext) = ctx.def_transform

CoreTypes.get_env_syms(ctx::GLSLPipelineContext) =
    vcat(
        map(var -> var[1], ctx.env_syms),
        map(decl -> decl.symbol.sym, ctx.interface_decls),
        (map(block -> keys(block.members), ctx.interface_blocks)...)...
    )

CoreTypes.add_helper!(ctx::GLSLPipelineContext, helper::Tuple{Expr,Any}) = push!(ctx.helpers, helper)
CoreTypes.get_helpers(ctx::GLSLPipelineContext) = ctx.helpers

CoreTypes.get_in_helper(ctx::GLSLPipelineContext) = ctx.in_helper
CoreTypes.set_in_helper!(ctx::GLSLPipelineContext, val::Bool) = (ctx.in_helper = val)

function CoreTypes.add_env_sym!(ctx::GLSLPipelineContext, name::Symbol, type::DataType)
    if any(es -> es[1] == name, ctx.env_syms)
        error("Trying to add already existing env sym to GLSL pipeline context: $name")
    end

    push!(ctx.env_syms, (name, type))
end

function CoreTypes.remove_env_sym!(ctx::GLSLPipelineContext, name::Symbol)
    idx = findfirst(es -> es[1] == name, ctx.env_syms)
    if isnothing(idx)
        error("Trying to remove non-existent env sym from GLSL pipeline context: $name")
    end

    popat!(ctx.env_syms, idx)
end

function CoreTypes.add_helper_ret_type!(ctx::GLSLPipelineContext, name::Symbol, sig::Tuple, ::Type{RetType}) where {RetType<:ASTType}
    key = (name, sig)

    if haskey(ctx.helper_sigs, key)
        error("Trying to define function $name with signature $sig multiple times")
    end

    ctx.helper_sigs[key] = RetType
end

CoreTypes.get_helper_ret_type(ctx::GLSLPipelineContext, name::Symbol, sig::Tuple) = get(ctx.helper_sigs, (name, sig), missing)

CoreTypes.is_i32_i64_swap_allowed(::GLSLPipelineContext) = true

function CoreTypes.get_env_sym_type(sym::Symbol, ctx::GLSLPipelineContext)
    type = nothing
    idx = findfirst(var -> var[1] == sym, ctx.env_syms)

    if !isnothing(idx)
        type = ctx.env_syms[idx][2]
    end

    if isnothing(type)
        idx = findfirst(decl -> decl.symbol.sym == sym, ctx.interface_decls)

        if !isnothing(idx)
            type = to_ast(ctx.interface_decls[idx].type)
        end
    end

    if isnothing(type)
        for block in ctx.interface_blocks
            if !isnothing(block.instance_name)
                continue
            end
            
            for member in block.members
                if member[1] == sym
                    return member[2][1]
                end
            end
        end
    end

    type
end
