@def_tagtype ScopedASTTypeTag DefaultTag

struct ExprTag <: ScopedASTTypeTag end
struct SymbolTag <: ScopedASTTypeTag end

@def_pre_rules(
    ScopedASTTypeTag,
    ScopedASTNode,
    (ExprTag, x -> x.original[] isa Expr),
    (SymbolTag, x -> x.original[] isa Symbol),
)
