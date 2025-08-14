export GLSLShaderContext

const GLSLVarList = Vector{Tuple{Symbol,DataType}}

struct GLSLShaderContext
    in_vars::GLSLVarList
    out_vars::GLSLVarList
    uniform_vars::GLSLVarList
end

GLSLShaderContext() = GLSLShaderContext(GLSLVarList(), GLSLVarList(), GLSLVarList())

function Base.string(ctx::GLSLShaderContext)
    result = ""

    result *= "Input variables:\n"
    if !isempty(ctx.in_vars)
        result *= var_list_to_str(ctx.in_vars) * "\n"
    end

    result *= "Output variables:\n"
    if !isempty(ctx.out_vars)
        result *= var_list_to_str(ctx.out_vars) * "\n"
    end

    result *= "Uniform variables:\n"
    if !isempty(ctx.uniform_vars)
        result *= var_list_to_str(ctx.uniform_vars) * "\n"
    end

    result
end

function var_list_to_str(var_list::GLSLVarList)::String
    result = ""

    for (var_sym, var_type) in var_list
        result *= " - $var_sym ($var_type)\n"
    end

    result[1:end-1]
end
