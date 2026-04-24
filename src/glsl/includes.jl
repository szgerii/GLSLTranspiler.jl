module GLSL

import ..GLSLTranspiler
using ..CoreTypes
using ..Utils
using ..TypeInference

using StaticArrays
using JuliaGLM

include("types/includes.jl")
include("builtin_fns.jl")

include("stages/glsl_preprocessor/includes.jl")
include("stages/glsl_transform/includes.jl")
include("stages/glsl_code_gen/includes.jl")

include("GLSLPipeline.jl")

end
