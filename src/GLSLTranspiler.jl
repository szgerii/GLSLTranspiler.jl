module GLSLTranspiler

using Tagger

# Types
include("typed_ast/types/ASTNodes.jl")
include("typed_ast/types/TASTNodes.jl")
include("typed_ast/VarData.jl")
include("typed_ast/TypeTree.jl")

# Utils
include("utils/ast_error.jl")
include("utils/print_ast.jl")

# Preprocessor
include("preprocessor/rules.jl")
include("preprocessor/transform.jl")
include("preprocessor/preprocessor.jl")

# TAST
include("typed_ast/scopes.jl")
include("typed_ast/rules.jl")
include("typed_ast/expr_transforms.jl")
include("typed_ast/build_tast.jl")

end
