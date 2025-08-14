@def_tagtype TASTNodeTag TASTDefault

struct TASTAssignmentTag <: TASTNodeTag end
struct TASTCallTag <: TASTNodeTag end
struct TASTBroadcastCallTag <: TASTNodeTag end
struct TASTReturnTag <: TASTNodeTag end
struct TASTTernaryTag <: TASTNodeTag end
struct TASTBlockTag <: TASTNodeTag end
struct TASTLogicalChainTag <: TASTNodeTag end
struct TASTRefTag <: TASTNodeTag end
struct TASTUnsupportedTag <: TASTNodeTag end

@def_pre_rules(
    TASTNodeTag,
    Expr,
    (TASTTernaryTag, ex -> begin
        ex.head == :if && all(.!isa.(ex.args, Expr) .|| getfield.(ex.args, :head) .!= :block)
    end),
    (TASTBroadcastCallTag, ex -> begin
        args_match = ex.head == :(.) && length(ex.args) == 2

        if !args_match
            return false
        end

        ex.args[1] isa Symbol && ex.args[2] isa Expr && ex.args[2].head == :tuple
    end),
)

@def_eqs(
    TASTNodeTag,
    (TASTAssignmentTag, :(=)),
    (TASTCallTag, :call),
    (TASTReturnTag, :return),
    (TASTBlockTag, :block),
    (TASTLogicalChainTag, :(&&), :(||)),
    (TASTRefTag, :ref),
    (TASTUnsupportedTag, :try)
)
