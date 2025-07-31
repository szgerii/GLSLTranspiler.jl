@def_tagtype PPNode PPDefault

struct UpdateAssignment <: PPNode end
struct StringCall <: PPNode end
struct ComparisonChain <: PPNode end

@def_eqs(
    PPNode,
    (StringCall, :string),
    (ComparisonChain, :comparison)
)

@def_pre_rules(
    PPNode,
    Expr,
    (UpdateAssignment, ex -> begin
        op = string(ex.head)
        length(op) > 1 && op[end] == '='
    end)
)
