@def_tagtype ASTConstructTag DefaultTag

struct SymbolTag <: ASTConstructTag end
struct LiteralTag <: ASTConstructTag end
struct BlockTag <: ASTConstructTag end
struct AssignmentTag <: ASTConstructTag end
struct CallTag <: ASTConstructTag end
struct ReturnTag <: ASTConstructTag end
struct DeclTag <: ASTConstructTag end
struct IfTag <: ASTConstructTag end
struct ForTag <: ASTConstructTag end
struct WhileTag <: ASTConstructTag end
struct SwizzleTag <: ASTConstructTag end
struct IndexerTag <: ASTConstructTag end
struct LogicalOperatorTag <: ASTConstructTag end
struct BreakTag <: ASTConstructTag end
struct ContinueTag <: ASTConstructTag end

@def_pre_rules(
    ASTConstructTag,
    TypedASTNode,
    (SymbolTag, node -> node.original[] isa Symbol),
    (LiteralTag, node -> node.original[] isa ASTLiteral),
    (IfTag, node -> begin
        expr = node.original[]

        if !(expr isa Expr) || expr.head != :if
            return false
        end

        arg_count = length(expr.args)

        if arg_count == 2
            return expr.args[2] isa Expr && expr.args[2].head == :block
        elseif arg_count == 3
            return expr.args[3] isa Expr && expr.args[3].head in [:elseif, :block]
        end

        return false
    end),
    (SwizzleTag, node -> begin
        expr = node.original[]

        if !(expr isa Expr) || expr.head != :ref
            return false
        end

        return node.children[2].type == ASTString
    end),
    (IndexerTag, node -> begin
        expr = node.original[]
        expr isa Expr && expr.head == :ref
    end),
    (LogicalOperatorTag, node -> begin
        expr = node.original[]

        expr isa Expr && expr.head == :call && expr.args[1] in [:(!), :(⊻)]
    end)
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
    (WhileTag, :while),
    (LogicalOperatorTag, :(&&), :(||)),
    (BreakTag, :break),
    (ContinueTag, :continue)
    #    (ForTag, :for),
)
