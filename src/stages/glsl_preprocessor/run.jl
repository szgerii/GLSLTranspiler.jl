import ....GLSLTranspiler: type_from_ast
import ....GLSLTranspiler.TypeInference: ASTValueType

is_expr_with_head(ex, head::Symbol) = ex isa Expr && ex.head == head

function run_glsl_preprocessor(mod::Module, pipeline_ctx::GLSLPipelineContext, ast::Expr)
    @assert ast.head == :function

    fdecl = ast.args[1]
    @assert fdecl.head == :call

    shader_ctx = GLSLShaderContext()

    params = fdecl.args[2:end]
    for (i, param) in enumerate(params)
        if !(param isa Expr) || param.head != :glsl_var
            continue
        end

        @assert length(param.args) == 3
        @assert all(arg -> arg isa QuoteNode, param.args)

        storage_qualifier = param.args[1].value
        pname = param.args[2].value
        ptype_sym = param.args[3].value

        ptype = type_from_ast(ptype_sym, mod)
        #@assert ptype <: ASTValueType "Invalid GLSL variable type: $ptype"

        target = nothing
        if storage_qualifier == :in
            target = shader_ctx.in_vars
        elseif storage_qualifier == :out
            target = shader_ctx.out_vars
        elseif storage_qualifier == :uniform
            target = shader_ctx.uniform_vars
        else
            ast_error(param, "Invalid storage qualifier found in parameter list (valid options are :in, :out and :uniform)")
        end

        push!(target, (pname, ptype))

        ast.args[1].args[i+1] = :($(pname)::$(ptype_sym))
    end

    pipeline_ctx.shader_ctx = shader_ctx

    ast
end
