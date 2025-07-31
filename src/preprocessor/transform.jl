preprocess_transform(::Type{PPDefault}, node::Expr, _::Module)::ASTNode = node

function preprocess_transform(::Type{PreUpdateAssignmentTag}, node::Expr, mod::Module)::ASTNode
    name = string(node.head)

    @assert length(name) > 1
    @assert name[end] == '='

    sub_op = Symbol(name[1:end-1])

    !isdefined(mod, sub_op) && ast_error(node, "Invalid update assignment operator: $hsym")

    lhs = node.args[1]
    rhs = node.args[2]

    sub_expr = Expr(:call, sub_op, lhs, rhs)
    new_node = Expr(:(=), lhs, sub_expr)

    new_node
end

preprocess_transform(::Type{PreStringCallTag}, node::Expr, _::Module)::ASTNode = Expr(:call, :string, node.args...)

function preprocess_transform(::Type{PreComparisonChainTag}, node::Expr, _::Module)::ASTNode
    n = length(node.args)
    args = [node.args[i] for i in 1:2:n]
    ops = [node.args[i] for i in 2:2:n-1]
    comps = [Expr(:call, ops[i], args[i], args[i+1]) for i in eachindex(ops)]

    @assert length(comps) > 1

    chain = Expr(:(&&), comps[1])
    gen_iter = Ref(chain)

    for i in 2:length(comps)-1
        push!(gen_iter[].args, Expr(:(&&), comps[i]))

        gen_iter = Ref(gen_iter[].args[2])
    end
    push!(gen_iter[].args, comps[end])

    chain
end
