module GLSLTranspiler

using Tagger

# TAST


# Utils
include("utils/ast_error.jl")
include("utils/print_ast.jl")

# Preprocessor
include("preprocessor/rules.jl")
include("preprocessor/transform.jl")
include("preprocessor/preprocessor.jl")

end
