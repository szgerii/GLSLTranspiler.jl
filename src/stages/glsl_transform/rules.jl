#=
@def_tagtype TypedASTTypeTag LiteralTag

struct ExprTag <: TypedASTTypeTag end
struct SymbolTag <: TypedASTTypeTag end
struct QuoteNodeTag <: TypedASTTypeTag end
struct LineNumberNodeTag <: TypedASTTypeTag end

@def_pre_rules(
    TypedASTTypeTag,
    TypedASTNode,
    (ExprTag, node -> node.original[] isa Expr),
    (SymbolTag, node -> node.original[] isa Symbol),
    (QuoteNodeTag, node -> node.original[] isa QuoteNode),
    (LineNumberNodeTag, node -> node.original[] isa LineNumberNode),
)
=#

@def_tagtype ASTConstructTag DefaultTag

struct SymbolTag <: ASTConstructTag end
struct LiteralTag <: ASTConstructTag end
struct BlockTag <: ASTConstructTag end
struct AssignmentTag <: ASTConstructTag end
struct CallTag <: ASTConstructTag end
struct ReturnTag <: ASTConstructTag end
struct DeclTag <: ASTConstructTag end
struct ForTag <: ASTConstructTag end
struct WhileTag <: ASTConstructTag end

@def_pre_rules(
    ASTConstructTag,
    TypedASTNode,
    (SymbolTag, node -> node.original[] isa Symbol),
    (LiteralTag, node -> node.original[] isa ASTLiteral),
)

Tagger.get_eq_projection(::Type{ASTConstructTag}, ::Type{TypedASTNode}) =
    node -> let expr = node.original[]
        expr isa Expr ? expr.head : nothing
    end

@def_eqs(
    ASTConstructTag,
    (BlockTag, :block),
    (AssignmentTag, :(=)),
    (CallTag, :call),
    (ReturnTag, :return),
    (DeclTag, :global, :local),
    (WhileTag, :while)
    #    (ForTag, :for),
)
