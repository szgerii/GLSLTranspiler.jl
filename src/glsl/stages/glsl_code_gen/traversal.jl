const infix_functions = [:+, :-, :*, :/, :%, :(<=), :(<), :(>), :(>=), :(==), :(!=)]

glsl_cg_traverse(node::GLSLEmptyNode, ctx::GLSLCodeGenContext) = ""

function glsl_cg_traverse(node::GLSLLiteral, ctx::GLSLCodeGenContext)
    if node.type <: GLSLVec
        vec = node.value
        @debug_assert vec isa JuliaGLM.VecNT

        n = length(vec)
        el_type = eltype(vec)
        vals = [vec...]
        
        @debug_assert el_type <: Union{Float32,Float64}
        ctor = (el_type == Float32 ? "vec" : "dvec") * string(n)

        return ctor * "(" * (allequal(vals) ? string(vals[1]) : join(vals, ", ")) * ")"
    elseif node.type <: GLSLMat
        mat = node.value
        @debug_assert mat isa JuliaGLM.MatTNxM

        (n, m) = size(mat)
        el_type = eltype(mat)
        vals = [mat...]

        @debug_assert el_type <: Union{Float32,Float64}
        ctor = (el_type == Float32 ? "mat" : "dmat") * string(n) * "x" * string(m)

        return ctor * "(" * (allequal(vals) ? string(vals[1]) : join(vals, ", ")) * ")"
    elseif node.type == GLSLDouble
        return string(node.value) * "lf"
    elseif node.type == GLSLUInt
        return string(node.value) * "u"
    end

    return string(node.value)
end

glsl_cg_traverse(node::GLSLSymbol, _::GLSLCodeGenContext) = string(node.sym)
glsl_cg_traverse(node::GLSLTypeSymbol, _::GLSLCodeGenContext) = type_to_str(node.type)

glsl_cg_traverse(node::GLSLNewLine, _::GLSLCodeGenContext) = repeat('\n', node.num_of_lines)

function glsl_cg_traverse(node::GLSLComment, ctx::GLSLCodeGenContext)
    if node.multiline
        padding = repeat(" ", ctx.indent_level + 4)
        content = padding * replace(node.content, '\n' => "\n" * padding)
        code = "/*\n" * content * "\n*/"
    else
        code = "// $(node.content)"
    end

    code
end

function glsl_cg_traverse(node::GLSLBlock, ctx::GLSLCodeGenContext)
    code = ""

    ctx.indent_level += 4
    padding = repeat(" ", ctx.indent_level)

    for expr in node.body
        if expr isa GLSLEmptyNode
            continue
        end

        expr_code = glsl_cg_traverse(expr, ctx)

        if isempty(strip(expr_code))
            continue
        end

        if !(expr isa GLSLBlock) && !(expr isa GLSLNewLine)
            expr_code = padding * expr_code
            expr_code = replace(expr_code, r"\n(?! )" => "\n" * padding)
        end

        if !(expr isa GLSLComment || expr isa GLSLNewLine) && expr_code[end] != '}'
            expr_code *= ";"
        end

        code *= expr_code * (expr isa GLSLNewLine ? "" : "\n")
    end

    ctx.indent_level -= 4

    code
end

function glsl_cg_traverse(node::GLSLDeclaration, ctx::GLSLCodeGenContext)
    qualifiers = qualifier_to_str.(sort_qualifiers(node.qualifiers))

    prefix = join(qualifiers, " ")
    if !isempty(qualifiers)
        prefix *= " "
    end

    suffix = ""
    if !isnothing(node.initial_value)
        suffix = " = " * glsl_cg_traverse(node.initial_value, ctx)
    end

    prefix * type_to_str(node.type) * " " * glsl_cg_traverse(node.symbol, ctx) * suffix
end

glsl_cg_traverse(node::GLSLAssignment, ctx::GLSLCodeGenContext) = "$(glsl_cg_traverse(node.lhs, ctx)) = $(glsl_cg_traverse(node.rhs, ctx))"

function glsl_cg_traverse(node::GLSLCall, ctx::GLSLCodeGenContext)::String
    if node.fn_name isa GLSLSymbol
        if node.fn_name.sym == :discard
            return "discard"
        elseif node.fn_name.sym == :length && length(node.args) == 1 && node.args[1] isa GLSLSymbol
            usym_idx = findfirst(usym -> usym.id == node.args[1].sym, ctx.usyms)
            usym = !isnothing(usym_idx) ? ctx.usyms[usym_idx] : nothing

            if !isnothing(usym) && to_glsl_type(usym.type) <: GLSLArray
                return string(usym.id) * ".length()"
            end
        end
    end

    code = ""
    is_infix = node.fn_name isa GLSLSymbol && node.fn_name.sym in infix_functions

    if !is_infix
        code *= "$(glsl_cg_traverse(node.fn_name, ctx))("
        code *= join(map(arg -> glsl_cg_traverse(arg, ctx), node.args), ",")
        code *= ")"
    else
        code *= "("
        code *= join(map(arg -> glsl_cg_traverse(arg, ctx), node.args), " $(glsl_cg_traverse(node.fn_name, ctx)) ")
        code *= ")"
    end

    code
end

function glsl_cg_traverse(node::GLSLReturn, ctx::GLSLCodeGenContext)
    code = "return"

    if !isnothing(node.body)
        code *= " " * glsl_cg_traverse(node.body, ctx)
    end

    code
end

glsl_cg_traverse(node::GLSLBreak, ::GLSLCodeGenContext) = "break"
glsl_cg_traverse(node::GLSLContinue, ::GLSLCodeGenContext) = "continue"

function glsl_cg_traverse(node::GLSLIf, ctx::GLSLCodeGenContext)
    code = "if (" * glsl_cg_traverse(node.condition, ctx) * ") {\n"
    code *= glsl_cg_traverse(node.body, ctx)
    code *= "}"

    for elseif_branch in node.elseif_branches
        code *= " else if (" * glsl_cg_traverse(elseif_branch.condition, ctx) * ") {\n"
        code *= glsl_cg_traverse(elseif_branch.body, ctx)
        code *= "}"
    end

    if !isnothing(node.else_branch)
        code *= " else {\n"
        code *= glsl_cg_traverse(node.else_branch, ctx)
        code *= "}"
    end

    code
end

function glsl_cg_traverse(node::GLSLWhile, ctx::GLSLCodeGenContext)
    code = "while ($(glsl_cg_traverse(node.condition, ctx))) {\n"
    code *= glsl_cg_traverse(node.body, ctx)
    code *= "}"

    code
end

function glsl_cg_traverse(node::GLSLLogicalAnd, ctx::GLSLCodeGenContext)
    glsl_cg_traverse(node.lhs, ctx) * " && " * glsl_cg_traverse(node.rhs, ctx)
end

function glsl_cg_traverse(node::GLSLLogicalOr, ctx::GLSLCodeGenContext)
    glsl_cg_traverse(node.lhs, ctx) * " || " * glsl_cg_traverse(node.rhs, ctx)
end

function glsl_cg_traverse(node::GLSLLogicalXor, ctx::GLSLCodeGenContext)
    glsl_cg_traverse(node.lhs, ctx) * " ^^ " * glsl_cg_traverse(node.rhs, ctx)
end

function glsl_cg_traverse(node::GLSLLogicalNeg, ctx::GLSLCodeGenContext)
    "!" * glsl_cg_traverse(node.body, ctx)
end

function glsl_cg_traverse(node::GLSLSwizzle, ctx::GLSLCodeGenContext)
    glsl_cg_traverse(node.base, ctx) * "." * node.swizzle
end

function glsl_cg_traverse(node::GLSLMatIndexer, ctx::GLSLCodeGenContext)
    code = glsl_cg_traverse(node.target, ctx) * "[$(glsl_cg_traverse(node.column, ctx))]"

    if !isnothing(node.row)
        code *= "[$(glsl_cg_traverse(node.row, ctx))]"
    end

    code
end

glsl_cg_traverse(node::GLSLArrayIndexer, ctx::GLSLCodeGenContext) =
    glsl_cg_traverse(node.target, ctx) * "[" * glsl_cg_traverse(node.index, ctx) * "]"

function glsl_cg_traverse(node::GLSLInterfaceBlock, ctx::GLSLCodeGenContext)
    qualifiers = qualifier_to_str.(sort_qualifiers(node.qualifiers))
    qualifiers_str = join(qualifiers, " ")
    
    code = qualifiers_str

    if !isempty(node.qualifiers)
        code *= " "
    end

    code *= glsl_cg_traverse(node.block_name, ctx) * " {\n"

    ctx.indent_level += 4
    padding = repeat(" ", ctx.indent_level)
    
    for member in node.members
        code *= padding * glsl_cg_traverse(member, ctx) * ";\n"
    end
    
    ctx.indent_level -= 4

    code *= "}"

    if !isnothing(node.instance_name)
        code *= " " * glsl_cg_traverse(node.instance_name, ctx)
    end

    if !isnothing(node.array_specifier)
        code *= "[" * glsl_cg_traverse(node.array_specifier, ctx) * "]"
    end

    code
end

function glsl_cg_traverse(node::GLSLLocalSizeDeclaration, ::GLSLCodeGenContext)
    "layout(local_size_x = " * string(node.dims[1]) *
    ", local_size_y = " * string(node.dims[2]) *
    ", local_size_z = " * string(node.dims[3]) * ") in"
end

function glsl_cg_traverse(node::GLSLArrayLiteral, ctx::GLSLCodeGenContext)
    el_strs = String[]
    for el in node.values
        push!(el_strs, glsl_cg_traverse(el, ctx))
    end

    type_to_str(node.el_type) * "[" * string(node.length) * "](" * join(el_strs, ",") * ")"
end
