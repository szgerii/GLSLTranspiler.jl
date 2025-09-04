@def_tagtype ScopeDiscoveryTag DefaultTag

struct HardTag <: ScopeDiscoveryTag end
struct SoftTag <: ScopeDiscoveryTag end
struct FnDefTag <: ScopeDiscoveryTag end

@def_eqs(
    ScopeDiscoveryTag,
    (SoftTag, :for, :while, :try),
    # :comprehension nodes are also supposed to introduce new hard scopes
    # but i couldn't find a case where a comprehension isn't just a wrapper for a :generator
    # so they are skipped for simplicity
    (HardTag, :function, :let, :(->), :generator),
)
