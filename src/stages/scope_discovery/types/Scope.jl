export IDChain, Scope, ScopeType, GLOBAL_SCOPE_ID, FUNCTION_SCOPE_ID, id_chain_string, same_scope, get_scope, get_root, in_hard_scope, is_global

const IDChain = Vector{UInt8}
const GLOBAL_SCOPE_ID::IDChain = [0x1]
const FUNCTION_SCOPE_ID::IDChain = [0x1, 0x1]

id_chain_string(id_chain::IDChain) = join(id_chain, '.')
function id_chain_string(id_chain::IDChain, selected_idx)
    @assert 1 <= selected_idx <= length(id_chain) "Index pointed outside of the id chain's bounds"

    pre = id_chain_string(id_chain[1:selected_idx-1])
    post = id_chain_string(id_chain[selected_idx+1:end])
    selected = (selected_idx > 1 ? "." : "") * "($(id_chain[selected_idx]))" * (selected_idx < length(id_chain) ? "." : "")

    pre * selected * post
end

@enum ScopeType ModuleScope HardScope SoftScope

struct Scope <: AbstractTree
    id_chain::IDChain
    children::Vector{Scope}
    parent::Union{Ref{Scope},Nothing}
    type::ScopeType

    # ctor for global scope (root node)
    Scope() = new(GLOBAL_SCOPE_ID, [], nothing, ModuleScope)

    # ctor for a sub-scope
    function Scope(parent::Ref{Scope}, type::ScopeType)
        new_id_chain = [parent[].id_chain..., length(parent[].children) + 1]
        new_child = new(new_id_chain, [], parent, type)
        push!(parent[].children, new_child)

        new_child
    end
end

Base.string(scope::Scope) = "Scope #$(join(scope.id_chain, '.')) ($(scope.type))"

scope_tree_string(scope::Ref{Scope}, indent=0) = scope_tree_string(scope[], indent)

function scope_tree_string(scope::Scope, indent=0)
    padding = repeat(' ', indent)
    scope_str = padding * "[" * string(scope) * "]"

    for child in get_children(scope)
        scope_str *= "\n" * scope_tree_string(child, indent + 2)
    end

    scope_str
end

same_scope(a::Scope, b::Scope) = a.id_chain == b.id_chain
same_scope(a::Ref{Scope}, b::Ref{Scope}) = same_scope(a[], b[])

function is_parent_of(child::IDChain, parent::IDChain)::Bool
    if length(child) <= length(parent)
        return false
    end

    for (i, p_id) in enumerate(parent)
        if p_id != child[i]
            return false
        end
    end

    return true
end

function get_scope(id_chain::IDChain, root::Ref{Scope})::Ref{Scope}
    iter = root

    # if we're starting from the scope tree root
    # ignore first idx (usually referring to the trivial root level)
    start_idx = isnothing(root[].parent) ? 2 : 1

    for (i, id) in enumerate(id_chain[start_idx:end])
        @assert 1 <= id <= length(iter[].children) "Invalid id in id_chain: $(id_chain_string(id_chain, i))"

        iter = iter[].children[id]
    end

    iter
end

function get_root(scope::Ref{Scope})::Ref{Scope}
    iter = scope

    while !isnothing(iter[].parent)
        iter = iter[].parent
    end

    iter
end

function in_hard_scope(scope::Ref{Scope})::Bool
    iter = scope

    while !isnothing(iter)
        if scope[].type == HardScope
            return true
        end

        iter = iter[].parent
    end

    return false
end

is_global(scope::Scope)::Bool = scope.type == ModuleScope
is_global(scope::Ref{Scope})::Bool = is_global(scope[])
