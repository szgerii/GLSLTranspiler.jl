mutable struct GLSLCodeGenContext
    defining_module::Module
    usyms::Vector{TypedUniqueSymbol}
    indent_level::Int
end

GLSLCodeGenContext(mod::Module, usyms::Vector{TypedUniqueSymbol}) = GLSLCodeGenContext(mod, usyms, 0)
