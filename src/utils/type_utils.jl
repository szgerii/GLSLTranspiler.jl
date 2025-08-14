export has_empty_ctor

has_empty_ctor(::Type{T}) where T = any(ctor -> ctor.sig == Tuple{Type{T}}, methods(T))
