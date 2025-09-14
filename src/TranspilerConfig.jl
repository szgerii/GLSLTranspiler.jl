@kwdef mutable struct TranspilerConfig
    # whether to replace literals like 2.0 with their 32-bit counterpart (2.0f0)
    literals_as_f32::Bool = true
    # whether to make function with their JuliaGLM library-counterpart whenever possible
    # e.g. automatically turn min(a,b) into JuliaGLM.min(a, b) 
    rewrite_to_glm::Bool = true
end

transpiler_config = TranspilerConfig()
