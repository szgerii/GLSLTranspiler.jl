export @interface, find_interface_block, add_interface_block, add_qualifier!, add_qualifiers!

const MembersDict = Dict{Symbol,Tuple{DataType,Vector{Qualifier}}}

struct InterfaceBlock
    block_name::Symbol
    members::MembersDict
    qualifiers::Vector{Qualifier}
    instance_name::Union{Symbol,Nothing}
    array_specifier::Union{Int,Nothing}

    function InterfaceBlock(
        block_name::Symbol, members::MembersDict, qualifiers::Vector{Qualifier},
        instance_name::Union{Symbol,Nothing}, array_specifier::Union{Int,Nothing}
    )
        if isnothing(instance_name) && !isnothing(array_specifier)
            error("Trying to construct InterfaceBlock that has an array specifier, but not an instance name")
        end

        for mem in values(members)
            if !(mem[1] <: GLSLType)
                error("Trying to construct InterfaceBlock with a non-GLSL typed member declaration. This is most likely an internal transpiler problem, please open an issue in the GitHub repo.")
            end
        end

        new(block_name, members, qualifiers, instance_name, array_specifier)
    end
end

InterfaceBlock(block_name::Symbol, qualifiers::Vector{Qualifier}) =
    InterfaceBlock(block_name, Dict(), qualifiers, nothing, nothing)

InterfaceBlock(block_name::Symbol, members::Dict{Symbol,GLSLType}, qualifiers::Vector{Qualifier}, instance_name::Union{Symbol,Nothing}=nothing) =
    InterfaceBlock(block_name, members, qualifiers, nothing, instance_name)

# storage for interface block formats recognized by the transpiler
# block_name => InterfaceBlock mapping
const __interface_blocks = Dict{Symbol,InterfaceBlock}()

# pull in BlockConflictStrategy enum instances
using ..Transpiler: BCS_Error, BCS_Overwrite, BCS_OverwriteWarning, BCS_Ignore, BCS_IgnoreWarning

const CFG_MSG_FOOTER = "\nChange TranspilerConfig.gl_block_conflict to customize how this situation is handled"

find_interface_block(block_name::Symbol) = get(__interface_blocks, block_name, nothing)

function add_interface_block(block::InterfaceBlock)
    name = block.block_name

    # check for same-block-name conflicts and handle them according to TranspilerConfig
    if haskey(__interface_blocks, name)
        strategy = Transpiler.transpiler_config.gl_block_conflict

        strategy == BCS_Error && error("Trying to redefine interface block with block name: ", name, CFG_MSG_FOOTER)
        strategy == BCS_OverwriteWarning && println(
            "Overwriting previously registered interface block with block name: ", name,
            "\nPrevious interface block:\n",
            __interface_blocks[name],
            CFG_MSG_FOOTER
        )

        if strategy in [BCS_IgnoreWarning, BCS_Ignore]
            strategy == BCS_IgnoreWarning && println(
                "Skipping registration of an interface block, because a block with the same name has already been registered: ", name,
                CFG_MSG_FOOTER
            )

            return
        end

        @debug_assert strategy in [BCS_Overwrite, BCS_OverwriteWarning]
    end

    __interface_blocks[name] = block
end

function add_qualifier!(block::InterfaceBlock, qualifier::Qualifier)
    qual_t = typeof(qualifier)
    for qual in block.qualifiers
        if typeof(qual) == qual_t
            error("Trying to add qualifier of type $qual_t to an interface block ($(block.block_name)) that already has a qualifier of the same type")
        end
    end

    push!(block.qualifiers, qualifier)
end

function add_qualifier!(block_name::Symbol, qualifier::Qualifier)
    block = find_interface_block(block_name)

    if isnothing(block)
        error("Trying to add qualifier to an interface block with the name of '$block_name', but the given block could not be found.")
    end

    add_qualifier!(block, qualifier)
end

function add_qualifiers!(block::InterfaceBlock, qualifiers::Vararg{Qualifier})
    for qual in qualifiers
        add_qualifier!(block, qual)
    end
end

function add_qualifiers!(block_name::Symbol, qualifiers::Vararg{Qualifier})
    block = find_interface_block(block_name)

    if isnothing(block)
        error("Trying to add qualifiers to an interface block with the name of '$block_name', but the given block could not be found.")
    end

    add_qualifiers!(block, qualifiers...)
end

#=
============================
Interface block Expr format:
============================
ASTSym := Union{QuoteNode,Symbol}

head = :(iface_blk)
args:
  [1]::ASTSym - the name of the interface block
  [2]::Vector{Qualifier} - a list of block-level qualifiers
  [3]::Vector{Tuple{ASTSym,DataType,Vector{Qualifier}}} - a list of block members defined through their name, type and member-level qualifier list
  [4]::Union{ASTSym,Nothing} - the optional instance name of the interface block declaration
  [5]::Union{Int,Nothing} - the optional array specifier of the interface block declaration
=#

# function interface_block_to_ast(block::InterfaceBlock)
#     member_list = Tuple{QuoteNode,DataType,Vector{Qualifier}}[]
#     
#     for mem in block.members
#         name = mem[1] isa Symbol ? QuoteNode(mem[1]) : mem[1]
#         type = mem[2][1]
#         qualifiers = mem[2][2]
# 
#         push!(member_list, (name, type, qualifiers))
#     end
#     
#     return Expr(
#         :gl_iface_blk,
#         QuoteNode(block.block_name),
#         block.qualifiers,
#         member_list,
#         !isnothing(block.instance_name) ? QuoteNode(block.block_name) : nothing,
#         block.array_specifier
#     )
# end


macro interface(block_name::Symbol, members::Expr, instance_name::Union{Symbol,Nothing}=nothing, array_specifier::Union{Int,Nothing}=nothing)
    members = macroexpand(__module__, members; recursive = true)
    
    if members.head != :tuple || !all(mem -> mem isa Expr && mem.head in [:(::), :decl], members.args)
        error(
            "Invalid @interface usage: members need to be provided as a tuple Expr of declarations.\n",
            "For example: @interface MyInterfaceBlock (x::Int, y::Float32, @readonly v::Vec3).\n"
        )
    elseif length(members.args) == 0
        error("Invalid @interface usage: cannot create memberless interface block.")
    end

    members_dict = MembersDict()
    for member in members.args
        name_sym = missing
        type = missing
        type_ast = missing
        qualifiers = Qualifier[]

        if member.head == :(::)
            name_sym = member.args[1]
            type_ast = member.args[2]
        elseif member.head == :decl
            if ismissing(member.args[2])
                error(
                    "Invalid @interface usage: trying to declare a member without type in the following :(decl) expression:\n",
                    member
                )
            end

            if !ismissing(member.args[3])
                error(
                    "Invalid @interface usage: trying to declare a member with an explicit scope in the following :(decl) expression:\n",
                    member
                )
            end

            if !isnothing(member.args[5])
                error(
                    "Invalid @interface usage: trying to declare a member with an initial value in the following :(decl) expression:\n",
                    member
                )
            end

            @debug_assert member.args[2] isa Type

            name_sym = member.args[1] isa QuoteNode ? member.args[1].value : member.args[1]
            type = to_glsl_type(member.args[2])
            qualifiers = member.args[4]
        end

        @debug_assert !ismissing(type) || !ismissing(type_ast)
        
        # TODO: parametric types

        if ismissing(type) && !ismissing(type_ast)
            resolved_type = missing

            is_sym = type_ast isa Symbol
            is_param_t = type_ast isa Expr && type_ast.head == :curly

            if is_sym || is_param_t
                inspected_modules = [__module__, Core, JuliaGLM, Base]

                if is_sym
                    for mod in inspected_modules
                        if isdefined(mod, type_ast) && (type_ref = getfield(mod, type_ast)) isa Type
                            resolved_type = type_ref
                        end
                    end
                elseif is_param_t
                    for mod in inspected_modules
                        try
                            resolved_type = mod.eval(type_ast)
                        catch
                        end
                    end
                end

                if ismissing(resolved_type)
                    error(
                        "Invalid @interface usage: the type symbol/expression used in the following member declaration appears to be invalid, or doesn't refer to a type:\n",
                        member, "\n",
                        "The referenced type has to be visible in one of the following modules: calling module, Core, JuliaGLM, Base"
                    )
                end
            else
                error(
                    "Invalid @interface usage: an unexpected AST node was received as type for member: ", name_sym, "\n",
                    "At the AST-level a member type should either be a Symbol or a :curly Expr (for parametric types)"
                )
            end

            @debug_assert !ismissing(resolved_type)
            type = to_glsl_type(resolved_type)
        end

        @debug_assert !ismissing(name_sym) && !ismissing(type)

        members_dict[name_sym] = (type, qualifiers)
    end

    @debug_assert !isempty(members_dict)

    block = InterfaceBlock(block_name, members_dict, Qualifier[], instance_name, array_specifier)

    add_interface_block(block)

    return block
end
