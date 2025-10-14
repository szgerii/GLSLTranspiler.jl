function qualifier_to_str(q::Qualifier)
    type_name = nameof(typeof(q))

    split(string(type_name), "Qualifier"; keepempty=false)[1] |> lowercase
end

qualifier_to_str(q::ConstantQualifier) = "const"

function qualifier_to_str(q::LayoutQualifier)
    result = "layout ("

    for option in q.options
        result *= string(option.name)

        if !isnothing(option.value)
            result *= " = $(option.value)"
        end

        result *= ", "
    end

    if !isempty(q.options)
        result = result[1:end-2]
    end

    result * ")"
end
