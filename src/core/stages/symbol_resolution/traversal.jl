"""
    collect_sym_usage!(ctx::SRContext, node::ScopedASTNode)

Collect usage information into `ctx` for every symbol in `node` and its children (recursively).
This means an ordered collection about how they appear in the code (decl, assignment or access).
"""
collect_sym_usage!(ctx::SRContext, node::ScopedASTNode) = collect_sym_usage!(ctx, node, tag_match(ScopedASTTypeTag, node))
collect_sym_usage!(_::SRContext, node::ScopedASTNode, ::Type{<:ScopedASTTypeTag}) = nothing

function collect_sym_usage!(ctx::SRContext, node::ScopedASTNode, ::Type{ExprTag})
    expr = node.original[]

    if node.has_own_scope
        scope_ctx = ScopeContext(ctx.defining_module, node.scope[].id_chain)

        traversal_root = node

        if expr.head == :function
            fname = expr.args[1].args[1]
            params = get_param_names(expr)

            for sym in [fname, params...]
                add_usage!(scope_ctx, sym, SymLocalDeclaration)
                add_usage!(scope_ctx, sym, SymAssignment)
            end

            # traverse only the body, not the declaration
            traversal_root = node.children[2]
        end

        collect_sym_usage_in_scope!(scope_ctx, traversal_root)
        ctx.scoped_sym_usages[node.scope[].id_chain] = scope_ctx.sym_usages
    end

    traversed_children = expr.head == :function ? node.children[2:end] : node.children
    for child in traversed_children
        collect_sym_usage!(ctx, child)
    end
end

"""
    collect_sym_usage_in_scope!(ctx::ScopeContext, node::ScopedASTNode)

Collect symbol usage information into `ctx`, but only in the [`Scope`](@ref) started by `node`.

`node` must be a scope-opening node.
"""
collect_sym_usage_in_scope!(ctx::ScopeContext, node::ScopedASTNode) = collect_sym_usage_in_scope!(ctx, node, tag_match(ScopedASTTypeTag, node))
collect_sym_usage_in_scope!(_::ScopeContext, node::ScopedASTNode, ::Type{<:ScopedASTTypeTag}) = nothing

function collect_sym_usage_in_scope!(ctx::ScopeContext, node::ScopedASTNode, ::Type{ExprTag})
    # stay inside the original scope
    if node.has_own_scope && node.scope[].id_chain != ctx.target_scope
        return
    end

    expr = node.original[]

    @debug_assert expr isa Expr

    children_to_traverse = node.children

    # ignore function names from function calls
    if expr.head == :call
        children_to_traverse = children_to_traverse[2:end]
    end

    if expr.head == :(=)
        collect_assignment!(ctx, node)
    elseif expr.head in [:global, :local]
        collect_declaration!(ctx, node)
    else
        for child in children_to_traverse
            collect_sym_usage_in_scope!(ctx, child)
        end
    end
end

function collect_sym_usage_in_scope!(ctx::ScopeContext, node::ScopedASTNode, ::Type{SymbolTag})
    sym = node.original[]

    @debug_assert sym isa Symbol

    if isdefined(ctx.defining_module, sym) && ctx.defining_module.eval(:($sym isa DataType || $sym isa Function))
        return
    end

    add_usage!(ctx, sym, SymAccess)
end

function collect_assignment!(ctx::ScopeContext, node::ScopedASTNode)
    lhs = node.original[].args[1]

    if lhs isa Expr && lhs.head == :ref
        return
    end

    @debug_assert lhs isa Symbol "Unexpected non-Symbol, non-ref AST node encountered in lhs of an assignment"

    rhs = node.children[2]

    collect_sym_usage_in_scope!(ctx, rhs)

    add_usage!(ctx, lhs, SymAssignment)
end

function collect_declaration!(ctx::ScopeContext, node::ScopedASTNode)
    expr = node.original[]

    decl_type = expr.head == :global ? SymGlobalDeclaration : SymLocalDeclaration

    target = expr.args[1]
    sym = missing
    if target isa Symbol
        sym = target
    elseif target isa Expr
        if target.head == :(::)
            sym = target.args[1]
        elseif target.head == :(=)
            sym = target.args[1] isa Symbol ? target.args[1] : target.args[1].args[1]
        elseif target.head == :decl
            sym = target.args[1].value
            
            if !ismissing(target.args[3])
                decl_type = target.args[3].value == :global ? SymGlobalDeclaration : SymLocalDeclaration
            end
        end
    end

    if ismissing(sym)
        ast_error(expr, "Encountered declaration with unexpected structure")
    end

    @debug_assert sym isa Symbol

    add_usage!(ctx, sym, decl_type)
end

