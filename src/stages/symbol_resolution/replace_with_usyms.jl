function replace_with_usyms!(node::ScopedASTNode, ctx::SRContext)
    for child in node.children
        replace_with_usyms!(child, ctx)
    end

    if node.original[] isa Symbol
        mappings = get(ctx.usym_mappings, node.scope[].id_chain, nothing)

        if isnothing(mappings)
            return
        end

        usym = get(mappings, node.original[], nothing)

        if isnothing(usym)
            return
        end

        node.original[] = usym.id
    end
end
