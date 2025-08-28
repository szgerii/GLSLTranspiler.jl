import ...SymbolResolution: USYM_INFIX

function run_glsl_transform(
    mod::Module, pipeline_ctx::GLSLPipelineContext, typed_ast::TypedASTNode, root_scope::Ref{Scope}, usyms::Vector{TypedUniqueSymbol}
)
    ctx = GTContext(mod)

    transform_state = glsl_traverse(typed_ast.children[2], ctx)

    glsl_ast = transform_state.glsl_node

    @assert glsl_ast isa GLSLBlock

    pushfirst!(glsl_ast.body, GLSLNewLine())
    pushfirst!(glsl_ast.body, GLSLComment("BODY", false))
    pushfirst!(glsl_ast.body, GLSLNewLine())

    params = get_param_names(typed_ast.original[])
    in_syms = map(var -> var[1], pipeline_ctx.shader_ctx.in_vars)
    out_syms = map(var -> var[1], pipeline_ctx.shader_ctx.out_vars)
    uniform_syms = map(var -> var[1], pipeline_ctx.shader_ctx.uniform_vars)

    interface_decls = GLSLDeclaration[]
    env_syms = get_env_syms(pipeline_ctx)

    for usym in usyms
        is_param = usym.original_sym in params && usym.def_scope_id == FUNCTION_SCOPE_ID
        in_global = usym.def_scope_id == GLOBAL_SCOPE_ID

        if usym.type == ASTFunction || in_global
            continue
        end

        sym_node = GLSLSymbol(usym.id)
        if is_param
            original_sym = split(string(usym.id), USYM_INFIX)[1] |> Symbol
            sq = (original_sym in in_syms ? SQ_In :
                  (original_sym in out_syms ? SQ_Out :
                   original_sym in uniform_syms ? SQ_Uniform : nothing))

            @assert !isnothing(sq)

            push!(interface_decls, GLSLDeclaration(sym_node, to_glsl_type(usym.type), sq))
        elseif !(sym_node.sym in env_syms)
            pushfirst!(glsl_ast.body, GLSLDeclaration(sym_node, to_glsl_type(usym.type)))
        end
    end

    pushfirst!(glsl_ast.body, GLSLNewLine())
    pushfirst!(glsl_ast.body, GLSLComment("USYM DECLARATIONS", false))
    pushfirst!(glsl_ast.body, GLSLNewLine())

    shader = GLSLShader(interface_decls, glsl_ast)

    (shader)
end

glsl_ast_string(misc::Any, indent=0) = repeat(' ', indent) * string(misc) * "\n"
glsl_ast_string(::Type{T}, indent=0) where T = repeat(' ', indent) * string(nameof(T)) * "\n"

function glsl_ast_string(node::GLSLASTNode, indent=0)::String
    padding = repeat(' ', indent)

    output = "$(padding)[$(nameof(typeof(node)))]\n"

    indent += 2
    for fieldname in fieldnames(typeof(node))
        output *= "$(padding)- $(fieldname):"

        field = getfield(node, fieldname)

        new_lined = field isa Vector || field isa GLSLASTNode
        sub_nodes = field isa Vector ? field : [field]

        if new_lined
            output *= "\n"
        end

        for sub_node in sub_nodes
            output *= glsl_ast_string(sub_node, new_lined ? indent + 2 : 1)
        end
    end

    output
end

precomp_subtypes(GLSLASTNode, glsl_ast_string, (missing, Int), false)
