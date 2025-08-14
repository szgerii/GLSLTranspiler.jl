import ..GLSLTranspiler

#! format: off
public glsl_pipeline
#! format: on

const glsl_pipeline = Pipeline("Julia -> GLSL",
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
