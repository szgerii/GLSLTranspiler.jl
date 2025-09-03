#! format: off
public glsl_pipeline
#! format: on

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
