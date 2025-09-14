@def_tagtype TASTNodeTag TASTDefault

struct TASTAssignmentTag <: TASTNodeTag end
struct TASTCallTag <: TASTNodeTag end
struct TASTReturnTag <: TASTNodeTag end
struct TASTTernaryTag <: TASTNodeTag end
struct TASTBlockTag <: TASTNodeTag end
struct TASTLogicalChainTag <: TASTNodeTag end
struct TASTRefTag <: TASTNodeTag end
struct TASTModuleResolveTag <: TASTNodeTag end
struct TASTFunctionDefTag <: TASTNodeTag end
struct TASTUnsupportedTag <: TASTNodeTag end

@def_pre_rules(
    TASTNodeTag,
    Expr,
    (TASTTernaryTag, ex -> begin
        ex.head == :if && all(.!isa.(ex.args, Expr) .|| getfield.(ex.args, :head) .!= :block)
    end)
)

@def_eqs(
    TASTNodeTag,
    (TASTAssignmentTag, :(=)),
    (TASTCallTag, :call),
    (TASTReturnTag, :return),
    (TASTBlockTag, :block),
    (TASTLogicalChainTag, :(&&), :(||)),
    (TASTRefTag, :ref),
    (TASTModuleResolveTag, :(.)),
    (TASTFunctionDefTag, :function),
    (TASTUnsupportedTag, :try)
)
