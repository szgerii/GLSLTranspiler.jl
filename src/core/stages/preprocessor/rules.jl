# Rules for traversing the AST for preprocessing

@def_tagtype PreprocessorTag DefaultPreTag

struct UpdateAssignmentTag <: PreprocessorTag end
struct StringCallTag <: PreprocessorTag end
struct ComparisonChainTag <: PreprocessorTag end
struct MultipleAssignmentTag <: PreprocessorTag end
struct MultipleTargetDeclTag <: PreprocessorTag end
struct BroadcastOperatorTag <: PreprocessorTag end
struct BroadcastCallTag <: PreprocessorTag end
struct PrefixNegTag <: PreprocessorTag end

@def_eqs(
    PreprocessorTag,
    (StringCallTag, :string),
    (ComparisonChainTag, :comparison)
)

@def_pre_rules(
    PreprocessorTag,
    Expr,
    (
        UpdateAssignmentTag,
        ex -> begin
            op = string(ex.head)
            length(op) > 1 && op[end] == '='
        end
    ),
    (
        MultipleAssignmentTag,
        ex -> (
            ex.head == :(=) &&
            let (lhs, rhs) = ex.args
                lhs isa Expr && rhs isa Expr && lhs.head == rhs.head == :tuple
            end
        )
    ),
    (
        MultipleTargetDeclTag,
        ex -> ex.head in [:global, :local] && length(ex.args) >= 2
    ),
    (
        BroadcastOperatorTag,
        ex -> ex.head == :call && startswith(string(ex.args[1]), '.')
    ),
    (
        BroadcastCallTag,
        ex -> begin
            args_match = ex.head == :(.) && length(ex.args) == 2

            if !args_match
                return false
            end

            ex.args[1] isa Symbol && ex.args[2] isa Expr && ex.args[2].head == :tuple
        end
    ),
    (
        PrefixNegTag,
        ex -> begin
            ex.head == :call && length(ex.args) == 2 && ex.args[1] == :(-)
        end
    )
)
