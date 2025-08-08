#! format: off
public glsl_pipeline
#! format: on

const glsl_pipeline = Pipeline("Julia -> GLSL",
    Vector([
        Preprocessor.PreprocessorStage,
        ScopeDiscovery.ScopeDiscoveryStage,
        SymbolResolution.SymbolResolutionStage,
        TypeInference.TypeInferenceStage
    ])
)
