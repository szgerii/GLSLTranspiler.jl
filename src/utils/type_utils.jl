export has_empty_ctor, unwrap_union

has_empty_ctor(::Type{T}) where T = any(ctor -> ctor.sig == Tuple{Type{T}}, methods(T))
unwrap_union(::Type{T}) where T = T isa Union ? vcat([T.a], unwrap_union(T.b)) : [T]
