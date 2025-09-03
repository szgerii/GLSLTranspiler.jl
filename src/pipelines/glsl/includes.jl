module GLSL

import ..Transpiler
using ..CoreTypes
using ..TypeInference

using JuliaGLM

include("GLSLShaderContext.jl")
include("GLSLPipelineContext.jl")
include("builtin_fns.jl")

include("../../stages/glsl_preprocessor/includes.jl")
include("../../stages/glsl_transform/includes.jl")
include("../../stages/glsl_code_gen/includes.jl")

include("glsl_pipeline.jl")
include("arg_macros.jl")

end
