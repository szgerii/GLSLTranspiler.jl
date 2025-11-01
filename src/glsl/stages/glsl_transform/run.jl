function run_glsl_transform(
    mod::Module, pipeline_ctx::GLSLPipelineContext, typed_ast::TypedASTNode, root_scope::Ref{Scope}, usyms::Vector{TypedUniqueSymbol}
)
    ctx = GTContext(mod, pipeline_ctx)

    transform_state = glsl_traverse(typed_ast.children[2], ctx)

    glsl_ast = transform_state.glsl_node

    @debug_assert glsl_ast isa GLSLBlock

    pushfirst!(glsl_ast.body, GLSLNewLine())
    pushfirst!(glsl_ast.body, GLSLComment("BODY", false))
    pushfirst!(glsl_ast.body, GLSLNewLine())

    fn_name = typed_ast.original[].args[1].args[1]
    params = get_param_names(typed_ast.original[])
    param_decls = GLSLDeclaration[]
    env_syms = get_env_syms(pipeline_ctx)
    in_helper = get_in_helper(pipeline_ctx)
    interface_blocks = pipeline_ctx.interface_blocks
    glsl_interface_blocks = GLSLInterfaceBlock[]

    for blk in interface_blocks
        member_decls = GLSLDeclaration[]

        for member in blk.members
            name = member[1]
            type = member[2][1]
            qualifiers = member[2][2]

            decl = GLSLDeclaration(GLSLSymbol(name), type, qualifiers)
            push!(member_decls, decl)
        end

        inst_name = !isnothing(blk.instance_name) ? GLSLSymbol(blk.instance_name) : nothing
        arr_spec = !isnothing(blk.array_specifier) ? GLSLLiteral(blk.array_specifier) : nothing

        glsl_blk = GLSLInterfaceBlock(GLSLSymbol(blk.block_name), blk.qualifiers, member_decls, inst_name, arr_spec)
        push!(glsl_interface_blocks, glsl_blk)
    end

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

            is_custom_decl = param_decl isa Expr && param_decl.head == :decl

            qualifiers = is_custom_decl ? param_decl.args[4] : Qualifier[]
            init_val = is_custom_decl && param_decl.args[5] isa QuoteNode ? GLSLLiteral(param_decl.args[5].value) : nothing

            if !in_helper && !any(q -> q isa Union{InQualifier,OutQualifier,UniformQualifier}, qualifiers)
                ast_error(param_decl, "Function acting as main entry point for GLSL shader cannot have parameters that are not marked with either in/out/uniform")
            end

            push!(param_decls, GLSLDeclaration(sym_node, to_glsl_type(usym.type), qualifiers, init_val))
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

    if in_helper && typed_ast.type == typed_ast.children[end].type && !(typed_ast.children[end].original[] isa Expr && typed_ast.children[end].original[].head == :return)
        glsl_ast.body[end] = GLSLReturn(glsl_ast.body[end])
    end

    local output
    if !in_helper
        output = GLSLShader(param_decls, glsl_interface_blocks, glsl_ast)

        for decl in pipeline_ctx.interface_decls
            pushfirst!(output.interface_declarations, decl)
        end
    else
        sort!(param_decls; by=decl -> begin
            idx = findfirst(param_sym -> param_sym == strip_usym_id(decl.symbol.sym), params)
        end)

        output = GLSLFunction(fn_name, param_decls, to_glsl_type(typed_ast.type), GLSLBlock(glsl_ast.body))
    end

    if !isnothing(pipeline_ctx.local_size)
        if in_helper
            error("@local_size declaration found in helper declaration, these are only valid in main function declarations.")
        end

        pushfirst!(output.interface_declarations, GLSLLocalSizeDeclaration(pipeline_ctx.local_size))
    end

    for usym in usyms
        if usym.def_scope_id == GLOBAL_SCOPE_ID
            pushfirst!(
                !in_helper ? output.interface_declarations : pipeline_ctx.interface_decls,
                GLSLDeclaration(GLSLSymbol(usym.id), to_glsl_type(usym.type), Qualifier[UniformQualifier()])
            )
        end
    end

    (output)
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
                var_sym = node.children[1].original[] isa Symbol ?
                          node.children[1].original[] :
                          node.children[1].children[1].original[]
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
