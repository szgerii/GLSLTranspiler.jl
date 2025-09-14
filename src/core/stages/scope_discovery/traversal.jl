# these constructs should introduce a new scope for their second :block arg, not for themselves directly
# e.g. a for loop's condition resides in the surrounding scope, not the scope defined by the loop
# TODO try, do, ->, generators/comprehensions
const LoweredScopeExprs = [:while, :for, :let]

# top to bottom traversal (except for the lowering logic)
function sd_traverse(node::Expr, ctx::SDContext)::ScopedASTNode
    old_scope = ctx.current_scope

    scoped_node = scope_transform(tag_match(ScopeDiscoveryTag, node), node, ctx)

    opened_new_scope = old_scope != ctx.current_scope
    should_lower = opened_new_scope && node.head in LoweredScopeExprs

    for child in node.args
        scoped_child_node = sd_traverse(child, ctx)
        push!(scoped_node.children, scoped_child_node)
    end

    # lower the scope to the body of the expression
    if should_lower
        body = scoped_node.children[2].original[]
        @assert body isa Expr && body.head == :block

        if node.head == :for
            loop_decl_scope = Scope(old_scope, LoopDeclScope)
            scoped_node.children[1].has_own_scope = true
            scoped_node.children[1].scope = Ref(loop_decl_scope)
        end

        scoped_node.children[2].has_own_scope = true
        scoped_node.children[2].scope = scoped_node.scope

        scoped_node.has_own_scope = false
        scoped_node.scope = old_scope

        target_scope = node.head == :for ? scoped_node.children[1].scope : old_scope
        trav_queue = [scoped_node.children[1]]
        while !isempty(trav_queue)
            current = popfirst!(trav_queue)

            current.scope = target_scope

            for child in current.children
                push!(trav_queue, child)
            end
        end

        ctx.current_scope = ctx.current_scope[].parent
    elseif opened_new_scope
        @assert !isnothing(ctx.current_scope[].parent) "Found unexpected module-level scope during scope detection"

        ctx.current_scope = ctx.current_scope[].parent
    end

    scoped_node
end

sd_traverse(node::ASTNode, ctx::SDContext)::ScopedASTNode = ScopedASTNode(Ref(node), ctx.current_scope)

precomp_union_types(Union{Symbol,ASTNode}, sd_traverse, (missing, SDContext))
