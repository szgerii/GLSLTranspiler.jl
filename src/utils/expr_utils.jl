export get_param_names

function get_param_names(f::Expr)::Vector{Symbol}
    params = Vector{ASTNode}()
    fdecl = f.args[1]

    for param_decl in fdecl.args[2:end]
        @assert param_decl isa Symbol || (param_decl isa Expr && param_decl.head == :(::))

        if param_decl isa Symbol
            push!(params, param_decl)
        elseif param_decl.head == :(::)
            push!(params, param_decl.args[1])
        end
    end

    params
end
