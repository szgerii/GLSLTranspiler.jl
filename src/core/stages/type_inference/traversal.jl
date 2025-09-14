gen_typed_ast(node::ScopedASTNode, ctx::TIContext) =
    gen_typed_ast(node, tag_match(ScopedASTTypeTag, node), ctx)

gen_typed_ast(node::ScopedASTNode, ::Type{T}, ctx::TIContext) where {T<:ScopedASTTypeTag} =
    ast_error(node.original[], "Unsupported AST node encountered: $T")

function gen_typed_ast(node::ScopedASTNode, ::Type{ExprTag}, ctx::TIContext)::TypedASTNode
    tag = tag_match(TASTNodeTag, node.original[])

    if tag == TASTUnsupportedTag
        ast_error(node, "Unsupported expression type: $(node.head)")
    end

    typed_node = TypedASTNode(node)

    for child in node.children
        child_node = gen_typed_ast(child, ctx)
        push!(typed_node.children, child_node)
    end

    infer_typed_ast_node!(typed_node, tag, ctx)

    typed_node
end

function gen_typed_ast(node::ScopedASTNode, ::Type{SymbolTag}, ctx::TIContext)::TypedASTNode
    tast_type = nothing

    # search in determined types...
    idx = find_usym_index(node.original[], ctx)

    if !isnothing(idx)
        tast_type = ctx.typed_usyms[idx][2]
    end

    # ...then among helper functions
    if has_helper(ctx.pipeline_ctx, node.original[])
        tast_type = ASTFunction
    end

    # ...then in the calling module's scope
    if isnothing(tast_type)
        look_in_global =
            !is_usym_id(node.original[]) ||
            (!isnothing(idx) && ctx.typed_usyms[idx][1].def_scope_id == GLOBAL_SCOPE_ID)

        sym = node.original[]
        if !isnothing(idx)
            sym = ctx.typed_usyms[idx][1].original_sym
        end

        if look_in_global && isdefined(ctx.defining_module, sym)
            tast_type = to_tast(typeof(ctx.defining_module.eval(sym)))
        end

        if !isnothing(tast_type) && is_usym_id(node.original[])
            add_type!(ctx, node.original[], tast_type)
        end
    end

    # if we found it in either, mark it as that type
    if !isnothing(tast_type)
        return TypedASTNode(node, tast_type)
    end

    # if we didn't, mark it as a void_sym (an undefined symbol)
    # we dont error here, as it could still be part of a valid expression (e.g. assignment lhs, function def)
    TypedASTNode(node, ASTVoidSym)
end

function gen_typed_ast(node::ScopedASTNode, ::Type{LiteralTag}, _::TIContext)::TypedASTNode
    src_type = typeof(node.original[])
    tast_type = to_tast(src_type)

    if isnothing(tast_type)
        ast_error(node, "Unsupported literal type: $src_type (for literal $node)")
    end

    TypedASTNode(node, tast_type)
end

function gen_typed_ast(node::ScopedASTNode, ::Type{QuoteNodeTag}, _::TIContext)::TypedASTNode
    TypedASTNode(node, ASTVoidSym)
end

precomp_subtypes(ScopedASTTypeTag, gen_typed_ast, (ScopedASTNode, missing, TIContext))
