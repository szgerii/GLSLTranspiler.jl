module Preprocessor

import ..GLSLTranspiler
using ..BaseTypes
using ..Utils
using Tagger

include("rules.jl")
include("transformations.jl")
include("traversal.jl")
include("run.jl")

const PreprocessorStage =
    Stage(
        "Preprocessor (AST -> AST)",
        run_preprocessor;
        output_names=["Preprocessed Function Definition"],
        output_formatters=[identity]
    )

end
