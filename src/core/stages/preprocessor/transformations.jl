preprocess_transform(::Type{DefaultPreTag}, node::Expr, _::Module)::Vector{ASTNode} = [node]

# x += 2  =>  x = x + 2
function preprocess_transform(::Type{UpdateAssignmentTag}, node::Expr, mod::Module)::Vector{ASTNode}
    name = string(node.head)

    @assert length(name) > 1
    @assert name[end] == '='

    sub_op = Symbol(name[1:end-1])

    !isdefined(mod, sub_op) && ast_error(node, "Invalid update assignment operator: $hsym")

    lhs = node.args[1]
    rhs = node.args[2]

    sub_expr = Expr(:call, sub_op, lhs, rhs)
    new_node = Expr(:(=), lhs, sub_expr)

    [new_node]
end

# turn string concat into simple function call to `string`
preprocess_transform(::Type{StringCallTag}, node::Expr, _::Module)::Vector{ASTNode} = Expr(:call, :string, node.args...)

# a < b < c  =>  a < b && b < c
function preprocess_transform(::Type{ComparisonChainTag}, node::Expr, _::Module)::Vector{ASTNode}
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

    [chain]
end

# a,b,c = 1,2,3  =>  a = 1 ; b = 2 ; c = 3
# note: this doesn't allow variables which appear on both sides of the assignment (e.g. swapping)
function preprocess_transform(::Type{MultipleAssignmentTag}, node::Expr, _::Module)::Vector{ASTNode}
    lhs_exprs = node.args[1].args
    rhs_exprs = node.args[2].args

    @assert length(lhs_exprs) == length(rhs_exprs)

    result = []

    for i in eachindex(lhs_exprs)
        lhs = lhs_exprs[i]
        rhs = rhs_exprs[i]

        if lhs in rhs_exprs
            ast_error(node, "Multiple assignment LHS found in RHS. The transpiler aims to keep a close equivalence with the generated code format-wise, so syntax like \"a,b = b,a\" is not allowed. Independent assignments like \"a,b = 0,1\" is allowed and will simply be \'unrolled\'.")
        end

        push!(result, Expr(:(=), lhs, rhs))
    end

    result
end

# global a,b  =>  global a ; global b
function preprocess_transform(::Type{MultipleTargetDeclTag}, node::Expr, _::Module)::Vector{ASTNode}
    result = []
    decl_type = node.head

    for arg in node.args
        decl = Expr(decl_type, arg)

        push!(result, decl)
    end

    result
end

# sin.(x)  =>  broadcast(sin, x)
function preprocess_transform(::Type{BroadcastOperatorTag}, node::Expr, _::Module)::Vector{ASTNode}
    @assert length(node.args) >= 2
    @assert node.args[1] isa Symbol

    op_sym = string(node.args[1])[2:end] |> Symbol
    args = node.args[2:end]

    [Expr(:call, :broadcast, op_sym, args...)]
end

function preprocess_transform(::Type{BroadcastCallTag}, node::Expr, _::Module)::Vector{ASTNode}
    fsym = node.args[1]
    args = node.args[2].args

    [Expr(:call, :broadcast, fsym, args...)]
end

# -x  =>  -1 * x
function preprocess_transform(::Type{PrefixNegTag}, node::Expr, _::Module)::Vector{ASTNode}
    [Expr(:call, :*, -1, node)]
end

precomp_subtypes(PreprocessorTag, preprocess_transform, (missing, Expr, Module))
