module GLSL

import ..Transpiler
using ..CoreTypes
using ..Utils
using ..TypeInference

using JuliaGLM

include("types/Qualifiers.jl")
include("types/ShaderVar.jl")
include("GLSLShaderContext.jl")
include("types/GLSLPipelineContext.jl")
include("builtin_fns.jl")

include("../../stages/glsl_preprocessor/includes.jl")
include("../../stages/glsl_transform/includes.jl")
include("../../stages/glsl_code_gen/includes.jl")

include("glsl_pipeline.jl")
include("arg_macros.jl")

end
