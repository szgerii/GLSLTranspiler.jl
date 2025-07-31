@def_tagtype PreTag PPDefault

struct PreUpdateAssignmentTag <: PreTag end
struct PreStringCallTag <: PreTag end
struct PreComparisonChainTag <: PreTag end

@def_eqs(
    PreTag,
    (PreStringCallTag, :string),
    (PreComparisonChainTag, :comparison)
)

@def_pre_rules(
    PreTag,
    Expr,
    (PreUpdateAssignmentTag, ex -> begin
        op = string(ex.head)
        length(op) > 1 && op[end] == '='
    end)
)
