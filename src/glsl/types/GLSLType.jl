export to_glsl_type

@exported abstract type GLSLType end

to_glsl_type(::Type{T}) where T = error("Julia type '$T' cannot be converted to a GLSL type")

@exported struct GLSLBool <: GLSLType end
@exported struct GLSLInt <: GLSLType end
@exported struct GLSLUInt <: GLSLType end
@exported struct GLSLFloat <: GLSLType end
@exported struct GLSLDouble <: GLSLType end

TypeInference.to_tast(::Type{T}) where {T <: GLSLType} = nothing
TypeInference.to_ast(::Type{T}) where {T <: GLSLType} = nothing

# TODO do this through a helper, like in TypeInference's AST node type mappings
to_glsl_type(::Type{<:Union{Bool,ASTBool}}) = GLSLBool
TypeInference.to_tast(::Type{GLSLBool}) = ASTBool
TypeInference.to_ast(::Type{GLSLBool}) = Bool
to_glsl_type(::Type{<:Union{Int32, Int64, ASTInt32, ASTInt64}}) = GLSLInt
TypeInference.to_tast(::Type{GLSLInt}) = ASTInt32
TypeInference.to_ast(::Type{GLSLInt}) = Int32
to_glsl_type(::Type{<:Union{UInt32, ASTUInt32}}) = GLSLUInt
TypeInference.to_tast(::Type{GLSLUInt}) = ASTUInt32
TypeInference.to_ast(::Type{GLSLUInt}) = UInt32
to_glsl_type(::Type{<:Union{Float32, ASTFloat32}}) = GLSLFloat
TypeInference.to_tast(::Type{GLSLFloat}) = ASTFloat32
TypeInference.to_ast(::Type{GLSLFloat}) = Float32
to_glsl_type(::Type{<:Union{Float64, ASTFloat64}}) = GLSLDouble
TypeInference.to_tast(::Type{GLSLDouble}) = ASTFloat64
TypeInference.to_ast(::Type{GLSLDouble}) = Float64

@exported abstract type GLSLVec <: GLSLType end

for n in 2:4
    for (suffix, _) in VEC_EL_TYPES
        tast_sym = Symbol("ASTVec", n, suffix)
        glsl_sym = Symbol("GLSLVec", n, suffix)
        glm_sym = Symbol(suffix == "F" ? "" : suffix, "Vec", n)

        @debug_assert isdefined(JuliaGLM, glm_sym) "Couldn't find type $glm_sym in JuliaGLM module"
        glm_type = getfield(JuliaGLM, glm_sym)

        @eval @exported struct $glsl_sym <: GLSLVec end
        @eval to_glsl_type(::Type{<:Union{$tast_sym, $glm_type}}) = $glsl_sym
        @eval TypeInference.to_ast(::Type{$glsl_sym}) = $glm_sym
        @eval TypeInference.to_tast(::Type{$glsl_sym}) = $tast_sym
    end
end

@exported abstract type GLSLMat <: GLSLType end

for n in 2:4
    for m in 2:4
        for suffix in ["F", "D"]
            tast_sym = Symbol("ASTMat", n, "x", m, suffix)
            glsl_sym = Symbol("GLSLMat", n, "x", m, suffix)
            glm_sym = Symbol(suffix == "F" ? "" : suffix, "Mat", n, "x", m)

            @debug_assert isdefined(JuliaGLM, glm_sym) "Couldn't find type $glm_sym in JuliaGLM module"
            glm_type = getfield(JuliaGLM, glm_sym)

            @eval @exported struct $glsl_sym <: GLSLMat end
            @eval to_glsl_type(::Type{<:Union{$tast_sym, $glm_type}}) = $glsl_sym
            @eval TypeInference.to_ast(::Type{$glsl_sym}) = $glm_sym
            @eval TypeInference.to_tast(::Type{$glsl_sym}) = $tast_sym
        end
    end
end
