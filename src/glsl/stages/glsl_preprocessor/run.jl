function run_glsl_preprocessor(mod::Module, pipeline_ctx::GLSLPipelineContext, ast::Expr)
    @debug_assert ast.head == :function

    fdecl = ast.args[1]
    @debug_assert fdecl isa Expr && fdecl.head == :call

    i = 1
    while i <= length(fdecl.args)
        param = fdecl.args[i]
        i += 1

        if !(param isa Expr)
            continue
        end

        if param.head == :decl
            param.args[3] = :param
            
            if any(qualifier -> qualifier isa Union{InQualifier,OutQualifier,UniformQualifier}, param.args[4])
                push!(pipeline_ctx.env_syms, (param.args[1].value, param.args[2]))
            end
        elseif param.head == :buffer_blk_decl
            block_name = param.args[1] isa QuoteNode ? param.args[1].value : param.args[1]

            block = find_interface_block(block_name)

            if isnothing(block)
                error("Buffer declaration refers to a non-registered interface block: $block_name")
            end

            if !any(qual -> qual isa BufferQualifier, block.qualifiers)
                push!(block.qualifiers, BufferQualifier())
            end

            
            push!(pipeline_ctx.interface_blocks, block)

            i -= 1
            deleteat!(fdecl.args, i)
        end
    end

    fbody = ast.args[2]
    @debug_assert fbody isa Expr && fbody.head == :block

    ast.args[1] = glsl_preprocess(ast.args[1], mod, pipeline_ctx)
    ast.args[2] = glsl_preprocess(fbody, mod, pipeline_ctx)

    ast
end
