using Logging

const SymResStageReturn = Tuple{ScopedASTNode,Ref{Scope},Vector{UniqueSymbol},ScopedUSymMapping}

function run_sr(mod::Module, scoped_ast::ScopedASTNode, root_scope::Ref{Scope})::SymResStageReturn
    ctx = SRContext(mod, root_scope)

    # collect how each symbol is used per scope
    collect_sym_usage!(ctx, scoped_ast)

    for scope in sort(collect(keys(ctx.scoped_sym_usages)))
        @debug "[Scope #$(id_chain_string(scope))]:"

        for (sym, usages) in ctx.scoped_sym_usages[scope]
            @debug "$sym =>"

            for usage in usages
                @debug "  $usage"
            end
        end
    end

    # generate usyms and mappings based on the collected info
    gen_usyms!(ctx)

    # replace the symbols with the generated usyms in the AST
    replace_with_usyms!(scoped_ast, ctx)

    (scoped_ast, root_scope, collect(values(ctx.usyms)), ctx.usym_mappings)
end

function usym_list_string(usyms::Vector{UniqueSymbol})::String
    output = ""

    for usym in usyms
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
            output *= "$padding  $sym => $usym_id\n"
        end
    end

    output[1:end-1]
end
