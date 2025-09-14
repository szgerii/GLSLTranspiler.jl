# for scoping rules, see: https://docs.julialang.org/en/v1/manual/variables-and-scoping/

@def_tagtype ScopeDiscoveryTag DefaultSDTag

struct HardTag <: ScopeDiscoveryTag end
struct SoftTag <: ScopeDiscoveryTag end
struct FnDefTag <: ScopeDiscoveryTag end

@def_eqs(
    ScopeDiscoveryTag,
    (SoftTag, :for, :while, :try),
    # :comprehension nodes are also supposed to introduce new hard scopes
    # but I couldn't find a case where a comprehension isn't just a wrapper for a :generator
    # so they are skipped for simplicity
    (HardTag, :function, :let, :(->), :generator),
)
