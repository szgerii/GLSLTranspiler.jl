"""
    replace_with_usyms!(node::ScopedASTNode, ctx::SRContext)

Replaces all [`Symbol`](@ref)s in `node` and its children with the [`UniqueSymbol`](@ref) they refer to, recursively.
"""
function replace_with_usyms!(node::ScopedASTNode, ctx::SRContext)
    ast_node = node.original[]

    is_sym_swizzle = ast_node isa Expr && ast_node.head == :ref && ast_node.args[2] isa QuoteNode
    
    if !is_sym_swizzle
        for child in node.children
            replace_with_usyms!(child, ctx)
        end
    else
        # don't replace swizzle symbols
        replace_with_usyms!(node.children[1], ctx)
    end

    mappings = get(ctx.usym_mappings, node.scope[].id_chain, nothing)

    if isnothing(mappings)
        return
    end

    sym = missing
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
