export to_glsl_type

@exported abstract type GLSLType end

@exported struct GLSLBool <: GLSLType end
@exported struct GLSLInt <: GLSLType end
@exported struct GLSLUInt <: GLSLType end
@exported struct GLSLFloat <: GLSLType end
@exported struct GLSLDouble <: GLSLType end

for n in 2:4
    for (suffix, _) in GLM_EL_VEC_TYPES
        sym = Symbol("GLSLVec", n, suffix)
        @eval @exported struct $sym <: GLSLType end
    end
end

to_glsl_type(::Type{T}) where {T<:ASTValueType} = error("AST value type '$T' cannot be converted to a GLSL type")
to_glsl_type(::Type{ASTBool}) = GLSLBool
to_glsl_type(::Type{ASTInt32}) = GLSLInt
to_glsl_type(::Type{ASTInt64}) = GLSLInt
to_glsl_type(::Type{ASTUInt32}) = GLSLUInt
to_glsl_type(::Type{ASTFloat32}) = GLSLFloat
to_glsl_type(::Type{ASTFloat64}) = GLSLDouble

for n in 2:4
    for (suffix, _) in GLM_EL_VEC_TYPES
        tast_sym = Symbol("ASTVec", n, suffix)
        glsl_sym = Symbol("GLSLVec", n, suffix)

        @eval to_glsl_type(::Type{$tast_sym}) = $glsl_sym
    end
end
