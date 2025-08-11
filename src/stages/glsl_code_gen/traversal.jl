const infix_functions = [:+, :-, :*, :/, :(<=), :(<), :(>), :(>=), :(==), :(!=)]

glsl_cg_traverse(node::GLSLEmptyNode, ctx::GLSLCodeGenContext) = ""

function glsl_cg_traverse(node::GLSLLiteral, ctx::GLSLCodeGenContext)
    suffix = ""

    if node.type == GLSLDouble
        suffix = "lf"
    elseif node.type == GLSLUInt
        suffix = "u"
    end

    string(node.value) * suffix
end

glsl_cg_traverse(node::GLSLSymbol, _::GLSLCodeGenContext) = string(node.sym)
glsl_cg_traverse(node::GLSLTypeSymbol, _::GLSLCodeGenContext) = type_to_str(node.type)

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

        if !(expr isa GLSLBlock)
            expr_code = padding * expr_code
            expr_code = replace(expr_code, r"\n(?! )" => "\n" * padding)
        end

        if !(expr isa GLSLComment) && expr_code[end] != '}'
            expr_code *= ";"
        end

        code *= expr_code * "\n"
    end

    ctx.indent_level -= 4

    code
end

glsl_cg_traverse(node::GLSLDeclaration, ctx::GLSLCodeGenContext) = type_to_str(node.type) * " " * glsl_cg_traverse(node.symbol, ctx)

glsl_cg_traverse(node::GLSLAssignment, ctx::GLSLCodeGenContext) = "$(glsl_cg_traverse(node.lhs, ctx)) = $(glsl_cg_traverse(node.rhs, ctx))"

function glsl_cg_traverse(node::GLSLCall, ctx::GLSLCodeGenContext)::String
    code = ""
    is_infix = node.fn_name isa GLSLSymbol && node.fn_name.sym in infix_functions

    if !is_infix
        code *= "$(glsl_cg_traverse(node.fn_name, ctx))("
        code *= join(map(arg -> glsl_cg_traverse(arg, ctx), node.args), ",")
        code *= ")"
    else
        code *= join(map(arg -> glsl_cg_traverse(arg, ctx), node.args), " $(glsl_cg_traverse(node.fn_name, ctx)) ")
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
