export ScopedASTTypeTag, ExprTag, SymbolTag, QuoteNodeTag, LineNumberNode, LiteralTag

@def_tagtype ScopedASTTypeTag LiteralTag

struct ExprTag <: ScopedASTTypeTag end
struct SymbolTag <: ScopedASTTypeTag end
struct QuoteNodeTag <: ScopedASTTypeTag end
struct LineNumberNodeTag <: ScopedASTTypeTag end

@def_pre_rules(
    ScopedASTTypeTag,
    ScopedASTNode,
    (ExprTag, x -> x.original[] isa Expr),
    (SymbolTag, x -> x.original[] isa Symbol),
    (QuoteNodeTag, x -> x.original[] isa QuoteNode),
    (LineNumberNodeTag, x -> x.original[] isa LineNumberNode),
)
