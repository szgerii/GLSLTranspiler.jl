module Preprocessor

using ..GLSLTranspiler.BaseTypes
using Tagger

include("rules.jl")
include("transformations.jl")
include("traversal.jl")
include("run.jl")

const PreprocessorStage = Stage("Preprocessor (AST -> AST)", run_preprocessor)

end
