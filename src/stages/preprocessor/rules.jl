@def_tagtype PreTag DefaultPreTag

struct UpdateAssignmentPreTag <: PreTag end
struct StringCallPreTag <: PreTag end
struct ComparisonChainPreTag <: PreTag end
struct MultipleAssignmentPreTag <: PreTag end
struct MultipleTargetDeclPreTag <: PreTag end

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
    )
)
