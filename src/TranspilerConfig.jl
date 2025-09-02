@kwdef mutable struct TranspilerConfig
    literals_as_f32::Bool = true
    rewrite_to_glm::Bool = true
end

transpiler_config = TranspilerConfig()
