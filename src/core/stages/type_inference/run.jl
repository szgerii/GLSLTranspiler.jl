const TypeInferStageRetType = Tuple{TypedASTNode,Ref{Scope},Vector{TypedUniqueSymbol}}

function run_type_inference(
    mod::Module, pipeline_ctx::PipelineContext, scoped_ast::ScopedASTNode,
    root_scope::Ref{Scope}, usyms::Vector{UniqueSymbol}, usym_table::ScopedUSymMapping
)::TypeInferStageRetType
    ctx = TIContext(mod, root_scope, map(usym -> (usym, nothing), usyms), usym_table, pipeline_ctx)

    # process declaration data first
    fdecl = scoped_ast.children[1].original[]

    fname = fdecl.args[1]
    add_type!(ctx, fname, ASTFunction)

    for param_decl in fdecl.args[2:end]
        if !(param_decl isa Expr)
            ast_error(scoped_ast.original[], "Couldn't transpile function without explicitly typed parameter '$param_decl'")
        end

        if !(param_decl.head in [:(::), :decl])
            ast_error(param_decl, "Unsupported parameter declaration")
        end

        type = missing
        if param_decl.head == :(::) # typed params
            name_sym = param_decl.args[1]
            type_sym = param_decl.args[2]

            @debug_assert type_sym isa Symbol

            src_type = getfield(mod, type_sym)
            type = to_tast(src_type)

            if isnothing(type)
                ast_error(param_decl, "Invalid method parameter type: $src_type (for parameter $name_sym)")
            end
        elseif param_decl.head == :decl # custom Transpiler decls
            name_sym = param_decl.args[1].value
            type = param_decl.args[2]

            @debug_assert type isa DataType && type <: ASTType
        end

        @debug_assert name_sym isa Symbol
        @debug_assert type isa DataType

        target_usym_id = get_usym_id(name_sym, FUNCTION_SCOPE_ID)
        idx = find_usym_index(target_usym_id, ctx)

        if isnothing(idx)
            target_usym_id = name_sym
            idx = find_usym_index(name_sym, ctx)
        end

        if isnothing(idx)
            ast_error(param_decl, "Unique symbol for param $name_sym was not found in the output of the symbol resolution stage")
        end

        add_type!(ctx, target_usym_id, type)
    end

    for env_sym in get_env_syms(pipeline_ctx)
        idx = findfirst(t_usym -> t_usym[1].id == env_sym, ctx.typed_usyms)
        @debug_assert !isnothing(idx) "Couldn't find environment symbol $env_sym in usym list"

        if isnothing(ctx.typed_usyms[idx][2])
            src_type = get_env_sym_type(env_sym, pipeline_ctx)
            if isnothing(src_type)
                error("Couldn't get type of environment symbol $env_sym from get_env_sym_type")
            end

            tast_type = to_tast(src_type)
            if isnothing(tast_type)
                error("Invalid environment symbol type $src_type for symbol $env_sym")
            end

            add_type!(ctx, env_sym, tast_type)
        end
    end

    typed_ast = TypedASTNode(scoped_ast)

    # clone fn declaration sub-tree without type inference
    push!(typed_ast.children, clone_subtree(scoped_ast.children[1]))

    # transform fn body sub-tree from scoped ast into typed ast
    push!(typed_ast.children, gen_typed_ast(scoped_ast.children[2], ctx))

    if !isempty(typed_ast.children[2].children)
        last_expr = typed_ast.children[2].children[end]

        if ctx.return_type != Nothing
            if last_expr.type != ctx.return_type
                ast_error(last_expr.original[],
                    "Invalid last statement in function: last statement's type ($(last_expr.type)) doesn't match the function's previously inferred return type ($rtype)")
            end
        else
            if !(last_expr.type <: ASTValueType || last_expr.type == ASTVoid)
                ast_error(last_expr.original[],
                    "Invalid last statement in function: the function's return type cannot be what is being inferred from the last statement ($(last_expr.type))")
            end

            ctx.return_type = last_expr.type
        end
    end

    typed_ast.children[2].type = ctx.return_type
    typed_ast.type = ctx.return_type

    typed_usyms = []
    for (usym, type) in ctx.typed_usyms
        if isnothing(type) && isnothing(findfirst(USYM_INFIX, string(usym.id))) && isdefined(mod, usym.id)
            src_type = mod.eval(:(typeof($(usym.id))))

            if !(src_type isa DataType) || (tast_type = to_tast(src_type)) === nothing
                error("Variable '$(usym.id)' captured from the global scope has illegal type $src_type.")
            end

            add_type!(ctx, usym, tast_type)
            type = tast_type
        end

        @debug_assert !isnothing(type) "Couldn't infer type for unique symbol '$(usym.id)'"

        push!(typed_usyms, TypedUniqueSymbol(usym, type))
    end

    return (typed_ast, ctx.root_scope, typed_usyms)
end

function clone_subtree(root::ScopedASTNode)::TypedASTNode
    if !(root.original[] isa Expr)
        return TypedASTNode(root)
    end

    typed_node = TypedASTNode(root)

    for child in root.children
        push!(typed_node.children, clone_subtree(child))
    end

    typed_node
end

function typed_usym_list_string(usyms::Vector{TypedUniqueSymbol})::String
    output = ""

    for usym in usyms
        output *= "$(usym.id)\n" *
                  "  - Type: $(usym.type)\n" *
                  "  - Original Symbol: $(usym.original_sym)\n" *
                  "  - Defining Scope: #$(id_chain_string(usym.def_scope_id))\n"
    end

    output[1:end-1]
end
