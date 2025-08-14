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

end
