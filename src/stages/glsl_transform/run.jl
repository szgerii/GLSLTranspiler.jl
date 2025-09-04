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
            param_decl = get_param(typed_ast.original[], original_sym)

            push!(interface_decls, GLSLDeclaration(sym_node, to_glsl_type(usym.type), param_decl.args[4]))
        elseif !(sym_node.sym in env_syms)
            decl = find_decl(typed_ast, sym_node.sym)

            qualifiers = Qualifier[]
            if !isnothing(decl) && decl.original[].head == :decl
                qualifiers = decl.children[4].original[]
            end

            pushfirst!(glsl_ast.body, GLSLDeclaration(sym_node, to_glsl_type(usym.type), qualifiers))
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

function find_decl(node::TypedASTNode, sym::Symbol)::Union{TypedASTNode,Nothing}
    if node.original[] isa Expr
        expr = node.original[]

        if expr.head in [:local, :global, :decl]
            if expr.head in [:local, :global]
                var_sym = node.children[1].original[] isa Symbol ? node.children[1].original[] : node.children[1].children[1].original[]
            else
                var_sym = node.children[1].original[].value
            end

            if var_sym == sym
                return node
            end
        end

        for child in node.children
            result = find_decl(child, sym)

            if !isnothing(result)
                return result
            end
        end
    end

    return nothing
end

precomp_subtypes(GLSLASTNode, glsl_ast_string, (missing, Int), false)
