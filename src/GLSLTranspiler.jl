module GLSLTranspiler
__precompile__()

using Tagger

include("../lib/GLM/glm.jl")

# Base Types
include("types/includes.jl")

using .BaseTypes

# Utils
include("utils/ast_error.jl")
include("utils/tree_print.jl")
include("utils/type_utils.jl")
include("utils/expr_utils.jl")
include("utils/type_from_ast.jl")
include("utils/skip.jl")
include("utils/exported.jl")

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

using PrecompileTools: @compile_workload

# TODO profile for weak spots
# Precompile
@compile_workload begin
    @transpile GLSL.glsl_pipeline function shadertoy_demo(
        GLSL.@out(a::Vec4),
        GLSL.@in(b::Float32),
        GLSL.@uniform(c::IVec2)
    )
    end
end

end
