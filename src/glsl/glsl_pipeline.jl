#! format: off
public glsl_pipeline
#! format: on

"""
The pipeline the can be ran using [`Transpiler.run_pipeline`](@ref) for Julia -> GLSL transpilation.

It's made up of the following stages:

1. GLSL Preprocessor (GLSL)
1. Preprocessor (Core)
1. Scope Discovery (Core)
1. Symbol Resolution (Core)
1. Type Inference (Core)
1. IR Transformation (GLSL)
1. Code Generation (GLSL)
"""
const glsl_pipeline = Pipeline("Julia -> GLSL",
    Vector([
        Transpiler.GLSL.GLSLPreprocessor.GLSLPreprocessorStage,
        Transpiler.Preprocessor.PreprocessorStage,
        Transpiler.ScopeDiscovery.ScopeDiscoveryStage,
        Transpiler.SymbolResolution.SymbolResolutionStage,
        Transpiler.TypeInference.TypeInferenceStage,
        Transpiler.GLSL.GLSLTransform.GLSLTransformStage,
        Transpiler.GLSL.GLSLCodeGen.GLSLCodeGenStage
    ]),
    Transpiler.GLSL.GLSLPipelineContext
)
