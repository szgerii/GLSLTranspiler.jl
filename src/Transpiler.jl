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
end

end
