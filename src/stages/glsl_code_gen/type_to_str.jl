import ..GLSLTranspiler.TypeInference

type_to_str(::Type{GLSLBool}) = "bool"
type_to_str(::Type{GLSLInt}) = "int"
type_to_str(::Type{GLSLUInt}) = "uint"
type_to_str(::Type{GLSLFloat}) = "float"
type_to_str(::Type{GLSLDouble}) = "double"

const GLM_VEC_PREFIXES = Dict(
    "F" => "",
    "D" => "d",
    "I" => "i",
    "U" => "u",
    "B" => "b"
)

for n in 2:4
    for (suffix, _) in TypeInference.GLM_EL_VEC_TYPES
        glsl_type = Symbol("GLSLVec", n, suffix)
        prefix = GLM_VEC_PREFIXES[suffix]
        type_str = "$(prefix)vec$n"

        @eval type_to_str(::Type{$glsl_type}) = $type_str
    end
end
