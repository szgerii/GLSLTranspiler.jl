export to_glsl_type

@exported abstract type GLSLType end

@exported struct GLSLBool <: GLSLType end
@exported struct GLSLInt <: GLSLType end
@exported struct GLSLUInt <: GLSLType end
@exported struct GLSLFloat <: GLSLType end
@exported struct GLSLDouble <: GLSLType end
@exported struct GLSLVec2 <: GLSLType end
@exported struct GLSLVec3 <: GLSLType end
@exported struct GLSLVec4 <: GLSLType end

to_glsl_type(::Type{T}) where {T<:ASTValueType} = error("AST value type '$T' cannot be converted to a GLSL type")
to_glsl_type(::Type{ASTBool}) = GLSLBool
to_glsl_type(::Type{ASTInt32}) = GLSLInt
to_glsl_type(::Type{ASTInt64}) = GLSLInt
to_glsl_type(::Type{ASTUInt32}) = GLSLUInt
to_glsl_type(::Type{ASTFloat32}) = GLSLFloat
to_glsl_type(::Type{ASTFloat64}) = GLSLDouble
to_glsl_type(::Type{ASTVec2}) = GLSLVec2
to_glsl_type(::Type{ASTVec3}) = GLSLVec3
to_glsl_type(::Type{ASTVec4}) = GLSLVec4
