export has_empty_ctor

"""
    has_empty_ctor(::Type{T}) -> Bool

Return whether `T` can be constructed without any parameters (i.e. `t = T()`).
"""
has_empty_ctor(::Type{T}) where T = any(ctor -> ctor.sig == Tuple{Type{T}}, methods(T))
