function replace_with_usyms!(node::ScopedASTNode, ctx::SRContext)
    for child in node.children
        replace_with_usyms!(child, ctx)
    end

    mappings = get(ctx.usym_mappings, node.scope[].id_chain, nothing)

    if isnothing(mappings)
        return
    end

    sym = missing
    ast_node = node.original[]
    if ast_node isa Symbol
        sym = ast_node
    elseif ast_node isa QuoteNode
        sym = ast_node.value
    end

    if ismissing(sym)
        return
    end

    usym_id = get(mappings, sym, nothing)

    if isnothing(usym_id)
        return
    end

    if node.original[] isa Symbol
        node.original[] = usym_id
    elseif node.original[] isa QuoteNode
        node.original[] = QuoteNode(usym_id)
    end
end
