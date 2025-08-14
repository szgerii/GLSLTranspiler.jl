import .GLSLTransform: GLSLStorageQualifier

function qualifier_to_str(q::GLSLStorageQualifier)
    if q == SQ_In
        return "in"
    elseif q == SQ_Out
        return "out"
    elseif q == SQ_Uniform
        return "uniform"
    elseif q == SQ_None
        return ""
    else
        error("Unknown storage qualifier value: $q")
    end
end
