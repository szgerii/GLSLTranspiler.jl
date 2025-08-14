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

using PrecompileTools: @setup_workload, @compile_workload

# TODO profile for weak spots
# Precompile
@compile_workload begin
    @transpile GLSL.glsl_pipeline function shadertoy_demo(
        GLSL.@out(frag_color::Vec4),
        GLSL.@uniform(time::Float32),
        GLSL.@uniform(resolution::IVec2)
    )
        uv = gl_FragCoord["xy"] ./ resolution

        col = 0.5f0 .+ 0.5f0 .* cos.(time .+ uv["xyx"] + Vec3(0, 2, 4))

        frag_color = Vec4(col, 1.0f0)
    end
end

end
