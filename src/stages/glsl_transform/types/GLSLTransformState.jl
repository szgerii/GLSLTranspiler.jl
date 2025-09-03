mutable struct GLSLTransformState <: WrapperTree
    original::ASTNodeRef
    typed_node::TypedASTNode
    glsl_node::Union{GLSLASTNode,Missing}
    children::Union{Vector{GLSLTransformState},Missing}
end

GLSLTransformState(typed_node::TypedASTNode) =
    GLSLTransformState(typed_node.original, typed_node, missing, missing)

GLSLTransformState(typed_node::TypedASTNode, glsl_node::GLSLASTNode, children::Vector{GLSLTransformState}) =
    GLSLTransformState(typed_node.original, typed_node, glsl_node, children)

map_glsl(states::Vector{GLSLTransformState}) = map(child -> child.glsl_node, states)

glsl_children(state::GLSLTransformState; first::Int=1, last::Int=lastindex(state.children)) =
    map_glsl(state.children[first:last])