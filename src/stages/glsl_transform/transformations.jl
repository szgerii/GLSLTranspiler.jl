function transform_children!(state::GLSLTransformState, ctx::GTContext)
    tnode = state.typed_node
    state.children = Vector{GLSLTransformState}(undef, length(tnode.children))

    for (i, child) in enumerate(tnode.children)
        child_state = GLSLTransformState(child)
        glsl_transform!(child_state, ctx)

        state.children[i] = child_state
    end
end

glsl_transform!(state::GLSLTransformState, ctx::GTContext) =
    glsl_transform!(state, tag_match(ASTConstructTag, state.typed_node), ctx)

function glsl_transform!(state::GLSLTransformState, ::Type{DefaultTag}, ctx::GTContext)
    println("Found untagged node:")
    println(tree_node_string(state.typed_node))
end

function glsl_transform!(state::GLSLTransformState, ::Type{LiteralTag}, ctx::GTContext)
    state.glsl_node = GLSLLiteral(state.typed_node.original[])
end

function glsl_transform!(state::GLSLTransformState, ::Type{SymbolTag}, ctx::GTContext)
    state.glsl_node = GLSLSymbol(state.typed_node.original[])
end

function glsl_transform!(state::GLSLTransformState, ::Type{BlockTag}, ctx::GTContext)
    transform_children!(state, ctx)

    state.glsl_node = GLSLBlock(glsl_children(state))
end

function glsl_transform!(state::GLSLTransformState, ::Type{AssignmentTag}, ctx::GTContext)
    transform_children!(state, ctx)

    @assert length(state.children) == 2
    @assert state.children[1].glsl_node isa GLSLSymbol

    state.glsl_node = GLSLAssignment(state.children[1].glsl_node, state.children[2].glsl_node)
end

function glsl_transform!(state::GLSLTransformState, ::Type{CallTag}, ctx::GTContext)
    transform_children!(state, ctx)

    @assert !isempty(state.children)
    @assert state.children[1].glsl_node isa GLSLSymbol

    @assert all(child -> child.typed_node.type <: ASTValueType, state.children[2:end])

    fsym = state.children[1].glsl_node.sym
    @assert isdefined(ctx.defining_module, fsym)

    # ctor calls
    type = ctx.defining_module.eval(:(typeof($fsym)))
    if type == DataType
        glsl_type = to_glsl_type(TypeInference.to_tast(getfield(ctx.defining_module, fsym)))
        state.children[1].glsl_node = GLSLTypeSymbol(glsl_type)
    end

    state.glsl_node = GLSLCall(state.children[1].glsl_node, glsl_children(state, first=2))
end

function glsl_transform!(state::GLSLTransformState, ::Type{ReturnTag}, ctx::GTContext)
    transform_children!(state, ctx)

    @assert length(state.children) == 1

    ret_node = state.children[1]
    ret_type = ret_node.typed_node.type

    @assert ret_type <: ASTValueType || ret_type == ASTVoid

    state.glsl_node = ret_type <: ASTValueType ? GLSLReturn(ret_node) : GLSLReturn(nothing)
end

function glsl_transform!(state::GLSLTransformState, ::Type{DeclTag}, ctx::GTContext)
    state.glsl_node = GLSLEmptyNode()
end

function glsl_transform!(state::GLSLTransformState, ::Type{WhileTag}, ctx::GTContext)
    transform_children!(state, ctx)

    @assert length(state.children) == 2
    @assert state.children[1].typed_node.type == ASTBool
    @assert state.children[2].glsl_node isa GLSLBlock

    state.glsl_node = GLSLWhile(state.children[1].glsl_node, state.children[2].glsl_node)
end

function glsl_transform!(state::GLSLTransformState, ::Type{ForTag}, ctx::GTContext)
    tnode = state.typed_node

    @assert length(tnode.children) == 2

    it = tnode.children[1]
    body = tnode.children[2]

    body_state = GLSLTransformState(body)
    glsl_transform!(body_state, ctx)


end
