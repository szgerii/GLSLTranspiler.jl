mutable struct GLSLCodeGenContext
    defining_module::Module
    indent_level::Int
end

GLSLCodeGenContext(mod::Module) = GLSLCodeGenContext(mod, 0)
