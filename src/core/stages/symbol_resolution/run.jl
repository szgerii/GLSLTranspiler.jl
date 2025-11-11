const SymResStageRetType = Tuple{ScopedASTNode,Ref{Scope},Vector{UniqueSymbol},ScopedUSymMapping}

function run_sr(mod::Module, pipeline_ctx::PipelineContext, scoped_ast::ScopedASTNode, root_scope::Ref{Scope})::SymResStageRetType
    ctx = SRContext(mod, root_scope)

    # register env symbols
    env_syms = get_env_syms(pipeline_ctx)
    for env_sym in env_syms
        usym = reg_env_usym!(ctx, env_sym)
        add_mapping!(ctx, env_sym, FUNCTION_SCOPE_ID, usym)
    end

    # register fn name and params
    fn_name = scoped_ast.original[].args[1].args[1]
    usym = reg_env_usym!(ctx, fn_name)
    add_mapping!(ctx, fn_name, FUNCTION_SCOPE_ID, usym)

    # collect how each symbol is used per scope
    collect_sym_usage!(ctx, scoped_ast)

    # generate usyms and mappings based on the collected info
    gen_usyms!(ctx)

    # replace the symbols with the generated usyms in the AST
    replace_with_usyms!(scoped_ast, ctx)

    (scoped_ast, root_scope, collect(values(ctx.usyms)), ctx.usym_mappings)
end

function usym_list_string(usyms::Vector{UniqueSymbol})::String
    output = ""

    for usym in usyms
        if startswith(string(usym.original_sym), "gl_")
            continue
        end

        output *= "$(usym.id)\n" *
                  "  - Original Symbol: $(usym.original_sym)\n" *
                  "  - Defining Scope: #$(id_chain_string(usym.def_scope_id))\n"
    end

    output[1:end-1]
end

function usym_mappings_string(mappings::ScopedUSymMapping)::String
    output = ""

    for scope_id in sort(collect(keys(mappings)))
        padding = repeat(' ', max(0, (length(scope_id) - 2) * 2))
        output *= "$padding[Scope #$(id_chain_string(scope_id))]:\n"

        for (sym, usym_id) in mappings[scope_id]
            if startswith(string(sym), "gl_")
                continue
            end

            output *= "$padding  $sym => $usym_id\n"
        end
    end

    output[1:end-1]
end
