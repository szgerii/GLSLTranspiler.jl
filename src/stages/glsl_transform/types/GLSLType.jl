export to_glsl_type

@exported abstract type GLSLType end

to_glsl_type(::Type{T}) where {T<:ASTValueType} = error("AST value type '$T' cannot be converted to a GLSL type")

@exported struct GLSLBool <: GLSLType end
@exported struct GLSLInt <: GLSLType end
@exported struct GLSLUInt <: GLSLType end
@exported struct GLSLFloat <: GLSLType end
@exported struct GLSLDouble <: GLSLType end

to_glsl_type(::Type{ASTBool}) = GLSLBool
to_glsl_type(::Type{ASTInt32}) = GLSLInt
to_glsl_type(::Type{ASTInt64}) = GLSLInt
to_glsl_type(::Type{ASTUInt32}) = GLSLUInt
to_glsl_type(::Type{ASTFloat32}) = GLSLFloat
to_glsl_type(::Type{ASTFloat64}) = GLSLDouble

for n in 2:4
    for (suffix, _) in VEC_EL_TYPES
        tast_sym = Symbol("ASTVec", n, suffix)
        glsl_sym = Symbol("GLSLVec", n, suffix)

        @eval @exported struct $glsl_sym <: GLSLType end
        @eval to_glsl_type(::Type{$tast_sym}) = $glsl_sym
    end
end


for n in 2:4
    for m in 2:4
        for suffix in ["F", "D"]
            tast_sym = Symbol("ASTMat", n, "x", m, suffix)
            glsl_sym = Symbol("GLSLMat", n, "x", m, suffix)

            @eval @exported struct $glsl_sym <: GLSLType end
            @eval to_glsl_type(::Type{$tast_sym}) = $glsl_sym
        end
    end
end
