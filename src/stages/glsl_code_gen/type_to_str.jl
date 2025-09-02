import ....GLSLTranspiler.TypeInference

type_to_str(::Type{GLSLBool}) = "bool"
type_to_str(::Type{GLSLInt}) = "int"
type_to_str(::Type{GLSLUInt}) = "uint"
type_to_str(::Type{GLSLFloat}) = "float"
type_to_str(::Type{GLSLDouble}) = "double"

const TYPE_PREFIXES = Dict(
    "F" => "",
    "D" => "d",
    "I" => "i",
    "U" => "u",
    "B" => "b"
)

# Vectors

for n in 2:4
    for (suffix, _) in TypeInference.VEC_EL_TYPES
        glsl_type = Symbol("GLSLVec", n, suffix)
        prefix = TYPE_PREFIXES[suffix]
        type_str = "$(prefix)vec$n"

        @eval type_to_str(::Type{$glsl_type}) = $type_str
    end
end

# Matrices

for n in 2:4
    for m in 2:4
        for suffix in ["F", "D"]
            glsl_type = Symbol("GLSLMat", n, "x", m, suffix)
            prefix = TYPE_PREFIXES[suffix]
            type_str = "$(prefix)mat$(n)x$(m)"

            @eval type_to_str(::Type{$glsl_type}) = $type_str
        end
    end
end
