function glsl_traverse(node::TypedASTNode, ctx::GTContext)::GLSLTransformState
    @debug_assert node.original[] isa Expr || node.original[] isa Symbol "Unsupported AST node type: $(typeof(node.original[]))"

    state = GLSLTransformState(node)

    glsl_transform!(state, ctx)

    state
end
