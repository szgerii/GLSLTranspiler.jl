export GLSLPipeline, @glsl

"""
The pipeline the can be ran using [`GLSLTranspiler.run_pipeline`](@ref) for Julia -> GLSL transpilation.

It's made up of the following stages:

1. GLSL Preprocessor (GLSL)
1. Preprocessor (Core)
1. Scope Discovery (Core)
1. Symbol Resolution (Core)
1. Type Inference (Core)
1. IR Transformation (GLSL)
1. Code Generation (GLSL)
"""
const GLSLPipeline = Pipeline("Julia -> GLSL",
    Vector([
        GLSLTranspiler.GLSL.GLSLPreprocessor.GLSLPreprocessorStage,
        GLSLTranspiler.Preprocessor.PreprocessorStage,
        GLSLTranspiler.ScopeDiscovery.ScopeDiscoveryStage,
        GLSLTranspiler.SymbolResolution.SymbolResolutionStage,
        GLSLTranspiler.TypeInference.TypeInferenceStage,
        GLSLTranspiler.GLSL.GLSLTransform.GLSLTransformStage,
        GLSLTranspiler.GLSL.GLSLCodeGen.GLSLCodeGenStage
    ]),
    GLSLTranspiler.GLSL.GLSLPipelineContext
)

"""
Shorthand for calling [`@transpile`](@ref) with [`GLSLPipeline`](@ref) as the target pipeline.
"""
macro glsl(f::Expr, log_level=GLSLTranspiler.Silent)
    def = gensym()
    output = gensym()
    helpers = gensym()

    quote
        ($def, $output, $helpers) = GLSLTranspiler.run_pipeline($GLSLPipeline, $(QuoteNode(f)), $__module__; log_level=$(esc(log_level)))

        $__module__.eval($def)

        for helper in $helpers
            $__module__.eval(helper[1])
        end

        $output
    end
end
