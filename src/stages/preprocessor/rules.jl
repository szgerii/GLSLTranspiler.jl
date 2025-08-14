@def_tagtype PreTag DefaultPreTag

struct UpdateAssignmentPreTag <: PreTag end
struct StringCallPreTag <: PreTag end
struct ComparisonChainPreTag <: PreTag end
struct MultipleAssignmentPreTag <: PreTag end
struct MultipleTargetDeclPreTag <: PreTag end
struct BroadcastOperatorPreTag <: PreTag end
struct BroadcastCallPreTag <: PreTag end
struct PrefixNegPreTag <: PreTag end

@def_eqs(
    PreTag,
    (StringCallPreTag, :string),
    (ComparisonChainPreTag, :comparison)
)

@def_pre_rules(
    PreTag,
    Expr,
    (
        UpdateAssignmentPreTag,
        ex -> begin
            op = string(ex.head)
            length(op) > 1 && op[end] == '='
        end
    ),
    (
        MultipleAssignmentPreTag,
        ex -> (
            ex.head == :(=) &&
            let (lhs, rhs) = ex.args
                lhs isa Expr && rhs isa Expr && lhs.head == rhs.head == :tuple
            end
        )
    ),
    (
        MultipleTargetDeclPreTag,
        ex -> ex.head in [:global, :local] && length(ex.args) >= 2
    ),
    (
        BroadcastOperatorPreTag,
        ex -> ex.head == :call && startswith(string(ex.args[1]), '.')
    ),
    (
        BroadcastCallPreTag,
        ex -> begin
            args_match = ex.head == :(.) && length(ex.args) == 2

            if !args_match
                return false
            end

            ex.args[1] isa Symbol && ex.args[2] isa Expr && ex.args[2].head == :tuple
        end
    ),
    (
        PrefixNegPreTag,
        ex -> begin
            ex.head == :call && length(ex.args) == 2 && ex.args[1] == :(-)
        end
    )
)
