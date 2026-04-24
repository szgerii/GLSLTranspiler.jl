#=

Symbol resolution is performed based on the following logic mostly.
This was put together through experimentation, as I couldn't find a comprehensive source on Julia's symbol resolution rules,
except for some basic ones. However, these rules should follow Julia's compiler pretty closely.
The logic is expanded in gen_usyms! with some GLSLTranspiler-specific things too (for handling built-in functions and env symbols, etc.)

determine target scope through strongest construct
decl > assign > access

if decl (e.g. local x)
  global -> module scope
  local -> current scope

if assign (e.g. x = 2)
  if defed above in non-global -> scope of that def
  if defed in global -> current scope
  if not defed -> current scope

if access (e.g. sin(x))
  if defed above in non-global or global -> scope of that def
  if not defed above -> error

extra checks:
no conflicting decls
has to be used after global decl at least once in non-decl context
if def in current scope and usage before assignment (and not fn param) -> error

=#

function gen_usyms!(ctx::SRContext)
    fn_scope = ctx.root_scope[].children[1]
    gen_usyms!(ctx, Ref(fn_scope))
end

"""
    gen_usyms!(ctx::SRContext, scope::Ref{Scope})

Generate [`UniqueSymbol`](@ref)s and mappings into `ctx` for the given `scope`.
"""
function gen_usyms!(ctx::SRContext, scope::Ref{Scope})
    sym_usages = ctx.scoped_sym_usages[scope[].id_chain]

    for (sym, usages) in sym_usages
        scope_source = get_strongest_usage(usages)

        if is_declaration(scope_source)
            for usage in usages
                if is_declaration(usage) && usage != scope_source
                    error("Found conflicting scope declarations (global/local) for symbol $sym in scope #$(id_chain_string(scope[].id_chain)).")
                end
            end

            if usages[end] == SymGlobalDeclaration
                error("Symbol '$sym' in scope $(id_chain_string(scope[].id_chain)) is last used in a global declaration expression.\n",
                    "This isn't allowed in Julia, as every global declaration must be followed by at least one other usage of that variable.")
            end
        end

        # at the end
        # usym == missing => error
        # usym == nothing => skip
        # usym isa UniqueSymbol => add mapping between sym and usym in the current scope
        usym = missing
        if sym in ctx.skipped_syms
            usym = nothing
        elseif scope_source == SymGlobalDeclaration
            @debug_assert isdefined(ctx.defining_module, sym) "Symbol '$sym' with global declaration couldn't be found in the defining module (scope #$(id_chain_string(scope[].id_chain)))"

            usym = get(ctx.usyms, get_usym_id(sym, GLOBAL_SCOPE_ID), nothing)

            if isnothing(usym)
                usym = reg_usym!(ctx, sym, get_root(scope))
            end
        elseif scope_source == SymLocalDeclaration
            if scope[].id_chain == FUNCTION_SCOPE_ID && sym in ctx.env_syms
                usym = nothing
            else
                usym = reg_usym!(ctx, sym, scope)
            end
        elseif scope_source == SymAssignment
            local_usym = find_usym_in_parents(sym, scope, ctx)

            if !isnothing(local_usym)
                usym = local_usym
            else
                usym = reg_usym!(ctx, sym, scope)
            end
        elseif scope_source == SymAccess
            local_usym = find_usym_in_parents(sym, scope, ctx)

            if !isnothing(local_usym)
                usym = local_usym
            elseif isdefined(ctx.defining_module, sym)
                usym = reg_usym!(ctx, sym, get_root(scope); skip_id_gen=true)
            else
                error("Couldn't find mapping for usage-only symbol '$sym' in scope #$(id_chain_string(scope[].id_chain)) ",
                    "A definition couldn't be found in an upper local scope, and it couldn't be captured from the defining module either.")
            end
        end

        @debug_assert !ismissing(usym) "Failed to determine mapping for symbol '$sym' in scope #$(id_chain_string(scope[].id_chain))"

        if isnothing(usym) || usym.id in ctx.env_syms
            continue
        end

        if usym.def_scope_id == scope[].id_chain
            for usage in usages
                if usage == SymAssignment
                    break
                end

                if usage == SymAccess
                    error("Symbol '$sym' accessed before definition in scope #$(id_chain_string(scope[].id_chain))")
                end
            end
        end

        add_mapping!(ctx, sym, scope, usym)
    end

    for child_scope in scope[].children
        gen_usyms!(ctx, Ref(child_scope))
    end
end

function get_strongest_usage(usages::Vector{SymbolUsage})::SymbolUsage
    @debug_assert !isempty(usages)

    strongest_usage = nothing
    max_strength = 0
    for usage in usages
        strength = get_usage_strength(usage)

        if strength > max_strength
            strongest_usage = usage
            max_strength = strength
        end
    end

    strongest_usage
end

get_usage_strength(usage::SymbolUsage) = get_usage_strength(Val(usage))
get_usage_strength(::Val{SymGlobalDeclaration}) = 3
get_usage_strength(::Val{SymLocalDeclaration}) = 3
get_usage_strength(::Val{SymAssignment}) = 2
get_usage_strength(::Val{SymAccess}) = 1
