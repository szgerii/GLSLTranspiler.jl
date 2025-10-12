@kwdef mutable struct TranspilerConfig
    # whether to replace 64-bit float literals (like 2.0) with their 32-bit counterpart (2.0f0)
    literals_as_f32::Bool = true
    # whether to make function calls use their JuliaGLM library implementations whenever possible
    # e.g. automatically turn min(a,b) into JuliaGLM.min(a, b) 
    gl_rewrite_to_glm::Bool = true
    
    # control shader header versioning through these two
    gl_version::Unsigned = 330
    gl_core::Bool        = true

    # whether transpile-time evaluation happens for const assignment rhs
    # e.g. `@constant global x = 2 + 1` will be automatically converted to `const int x = 3`
    # this supports any time of expression on the rhs, as long as it returns a literal value
    # (and can be evaluated at transpile-time)
    gl_const_eval::Bool = true
end

global transpiler_config::TranspilerConfig = TranspilerConfig()
