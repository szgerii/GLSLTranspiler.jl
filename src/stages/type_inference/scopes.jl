const VarDict = Dict{String,VarData}

@enum ScopeType SOFT_SCOPE HARD_SCOPE GLOBAL_SCOPE

struct Scope
    id_chain::Vector{UInt8}
    vars::VarDict
    children::Vector{Ref{Scope}}
    parent::Union{Ref{Scope},Nothing}
    type::ScopeType

    # root ctor
    Scope(id::UInt8, type::ScopeType=GLOBAL_SCOPE) = new([id], VarDict(), [], nothing, type)

    # subnode ctor
    function Scope(id_chain::Vector{UInt8}, parent::Ref{Scope}, type::ScopeType)
        @assert length(id_chain) > 1
        @assert id_chain[1:end-1] == parent[].id_chain

        new(id_chain, VarDict(), [], parent, type)
    end
end

function Scope(parent::Ref{Scope}, type::ScopeType)
    id_suffix = convert(UInt8, length(parent[].children) + 1)
    s = Scope([parent[].id_chain..., id_suffix], parent, type)
    push!(parent[].children, s)
    s
end

struct ScopeTree
    glob::Ref{Scope}

    function ScopeTree()
        global_scope = Scope(0x1)

        # create function scope inside global scope
        Scope(Ref(global_scope), HARD_SCOPE)

        new(global_scope)
    end
end

get_fn_scope(st::ScopeTree)::Scope = st.glob[].children[1][]

function get_scope(st::ScopeTree, id_chain::Vector{UInt8})::Scope
    iter = st.glob

    for id in id_chain
        iter_val = iter[]

        id > length(iter_val.children) && error("Invalid ID chain: $id in $id_chain pointed to an invalid child scope")

        iter = iter_val.children[id]
    end

    iter[]
end

function get_var_data(name::String, scope::Scope)::Union{VarData,Nothing}
    if haskey(scope.vars, name)
        return scope.vars[name]
    end

    if isnothing(scope.parent)
        return nothing
    end

    get_var_data(name, scope.parent[])
end

print_scope_tree(st::ScopeTree) = print_scope_tree(st.glob[])
print_scope_tree(s::Ref{Scope}) = print_scope_tree(s[])

function print_scope_tree(scope::Scope)
    println("(Scope #", join(scope.id_chain, '.'), ")")

    for (name, vdata) in scope.vars
        println("$name : ", vdata.type)
    end

    for child_scope in scope.children
        print_scope_tree(child_scope)
    end
end
