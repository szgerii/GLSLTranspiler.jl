module Transpiler

# Common Types
include("core/types/includes.jl")

using .CoreTypes

# Utils
include("utils/includes.jl")

using .Utils

# Config
include("TranspilerConfig.jl")

# Preprocessor
include("core/stages/preprocessor/includes.jl")

# Scope Discovery
include("core/stages/scope_discovery/includes.jl")

# Symbol Resolution
include("core/stages/symbol_resolution/includes.jl")

# Type Inference
include("core/stages/type_inference/includes.jl")

# GLSL-specific stuff
include("glsl/includes.jl")

# Public API for transpilation
include("pipeline_runner.jl")

# Sample shader precompilation for speeding up TTFX
# see the Known Issues section in README.md for possible improvement routes

using JuliaGLM
using StaticArrays
using PrecompileTools: @compile_workload

_precomp_global = 0.0f0

using .GLSL

# TODO profile for weak spots
# Precompile
@compile_workload begin
    @transpile GLSL.GLSLPipeline function shadertoy_demo(
        GLSL.@out(a::Vec4),
        @in(@layout std430 (binding=0) (location=0) b::Float32),
        @uniform(c::IVec2)
    )
        _precomp_global

        @constant global const_var::Int64 = 2
        local x::Int64
        x = 2
        y = 2.0f0
        z = 2.0

        v2 = vec2(0)
        v3 = vec3(0)
        v4 = vec4(0)

        if false
            x = 0
        elseif false
            x = 0
        else
            x = 0
        end

        while false
            x = 0
        end

        y = sin(y)

        v2 = v2["xy"]
        v2 = v3["xy"]
        v2 = v4["xy"]

        v2 = v2[:xy]
        v2 = v3[:xy]
        v2 = v4[:xy]

        y = v2[1]
        y = v3[1]
        y = v4[1]
    end

    @interface TRANSPILER_PRECOMP_SSBO (JG_TESS_pos_arr::SVector{Vec3},)
    add_qualifiers!(:TRANSPILER_PRECOMP_SSBO,
            LayoutQualifier([
                LayoutQualifierOption(:std430),
                LayoutQualifierOption(:binding, 0)
            ]),
            RestrictQualifier(),
            WriteOnlyQualifier()
        )

    @transpile GLSL.GLSLPipeline function callback_fn( @uniform(JG_TESS_t_idx::UVec2), @uniform(JG_TESS_t_range::Vec2), @uniform(center::Vec3T{Float32}), @local_size(256), @uniform(JG_TESS_n::UInt32), @buffer(TRANSPILER_PRECOMP_SSBO))
        begin
            JG_TESS_ID = gl_GlobalInvocationID[:x]
            if JG_TESS_ID >= JG_TESS_n
                return
            end
        end
        begin
            JG_TESS_start_idx = JG_TESS_t_idx[:x]
            JG_TESS_end_idx = JG_TESS_t_idx[:y]
            JG_TESS_t_start = JG_TESS_t_range[:x]
            JG_TESS_t_end = JG_TESS_t_range[:y]
            JG_TESS_idx = JG_TESS_start_idx + JG_TESS_ID
            JG_TESS_t1 = Float32(JG_TESS_idx - JG_TESS_start_idx)
            JG_TESS_t2 = Float32(JG_TESS_end_idx - JG_TESS_start_idx)
            phi = (JG_TESS_t1 / JG_TESS_t2) * (JG_TESS_t_end - JG_TESS_t_start) + JG_TESS_t_start
        end
        r = cos(9phi) + 2
        x = r * cos(8phi)
        y = r * sin(8phi)
        z = -(sin(9phi))
        JG_TESS_pos_arr[JG_TESS_ID + 1] = center[:xyz] + vec3(x, y, z)
    end
end

end
