mutable struct SDContext
    definining_module::Module
    root_scope::Ref{Scope}
    current_scope::Ref{Scope}
    new_symbol_allowed::Bool
end

function SDContext(defining_module::Module)
    root = Scope()

    SDContext(defining_module, Ref(root), Ref(root), false)
end
