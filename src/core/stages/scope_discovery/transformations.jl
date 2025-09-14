scope_transform(::Type{DefaultSDTag}, node::ASTNode, ctx::SDContext) = ScopedASTNode(Ref(node), ctx.current_scope, false)

function scope_transform(::Type{T}, node::ASTNode, ctx::SDContext)::ScopedASTNode where {T<:Union{HardTag,SoftTag}}
    new_scope = Scope(ctx.current_scope, T == HardTag ? HardScope : SoftScope)
    ctx.current_scope = new_scope

    ScopedASTNode(Ref(node), ctx.current_scope, true)
end
