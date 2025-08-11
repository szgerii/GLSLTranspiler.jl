function run_glsl_transform(
    mod::Module, typed_ast::TypedASTNode, root_scope::Ref{Scope}, usyms::Vector{TypedUniqueSymbol}
)
    ctx = GTContext(mod)

    transform_state = glsl_traverse(typed_ast.children[2], ctx)

    glsl_ast = transform_state.glsl_node

    @assert glsl_ast isa GLSLBlock

    params = get_param_names(typed_ast.original[])

    pushfirst!(glsl_ast.body, GLSLComment("BODY", true))

    for usym in usyms
        is_param = usym.original_sym in params && usym.def_scope_id == FUNCTION_SCOPE_ID
        in_global = usym.def_scope_id == GLOBAL_SCOPE_ID

        if usym.type == ASTFunction || is_param || in_global
            continue
        end

        sym = GLSLSymbol(usym.id)
        pushfirst!(glsl_ast.body, GLSLDeclaration(sym, to_glsl_type(usym.type)))
    end

    pushfirst!(glsl_ast.body, GLSLComment("DECLARATIONS", true))

    (glsl_ast)
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
