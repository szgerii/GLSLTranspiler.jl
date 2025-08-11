function run_glsl_code_gen(mod::Module, glsl_ast::GLSLASTNode)::String
    ctx = GLSLCodeGenContext(mod)

    code = "void main() {\n"
    code *= glsl_cg_traverse(glsl_ast, ctx)
    code *= "}"

    code
end
