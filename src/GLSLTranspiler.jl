module GLSLTranspiler

using Tagger

include("utils/type_utils.jl")

# Base Types
include("types/includes.jl")

using .BaseTypes

# Utils
# TODO: move every util fn here
module Utils
include("utils/precomp_utils.jl")
end

include("utils/ast_error.jl")
include("utils/tree_print.jl")
include("utils/expr_utils.jl")
include("utils/type_from_ast.jl")
include("utils/skip.jl")
include("utils/exported.jl")

include("TranspilerConfig.jl")

# Preprocessor
include("stages/preprocessor/includes.jl")

# Scope Discovery
include("stages/scope_discovery/includes.jl")

# Symbol Resolution
include("stages/symbol_resolution/includes.jl")

# Type Inference
include("stages/type_inference/includes.jl")

# GLSL-specific stuff
include("pipelines/glsl/includes.jl")

# Public API stuff for transpilation
include("transpile.jl")

using JuliaGLM
using PrecompileTools: @compile_workload

_precomp_global = 0.0f0

# TODO profile for weak spots
# Precompile
@compile_workload begin
    @transpile GLSL.glsl_pipeline function shadertoy_demo(
        GLSL.@out(a::Vec4),
        GLSL.@in(b::Float32),
        GLSL.@uniform(c::IVec2)
    )
        global _precomp_global
        _precomp_global = 0.0f0

        local x
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
