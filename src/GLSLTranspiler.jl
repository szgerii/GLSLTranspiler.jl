module GLSLTranspiler

using Tagger

# GL and GLM helpers
# mainly needed for adding support to the types
include("../lib/GLM/glm.jl")
# include("../lib/GL/gl.jl")

# Base Types
include("types/includes.jl")

using .BaseTypes

# Utils
include("utils/ast_error.jl")
include("utils/tree_print.jl")
include("utils/expr_utils.jl")
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

# GLSL AST Transformation
include("stages/glsl_transform/includes.jl")

# GLSL Code Generation
include("stages/glsl_code_gen/includes.jl")

# Pipelines
include("pipelines/glsl_pipeline.jl")

# Public API stuff for transpilation
include("transpile.jl")

end
