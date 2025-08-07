# GLSLTranspiler.jl

TODO: usage, general description, structure of AST types

## AST types

### Julia AST

This is simply the built-in AST defined by Julia's Exprs, Symbols, etc.

### Scoped AST (SAST)

### Typed AST (TAST)

This is a wrapper for the Julia AST that already contains inferred type information for every node in the tree.

### IR AST

An intermediate representation type that is no longer structured in the same way Julia structures its code.
It's somewhere between the Julia AST and the GLSL AST, removed enough from the original to allow easy code generation into GLSL shader code.

## Stages

1. Preprocessor (Julia AST -> Julia AST)

    This stage is mainly used for converting language constructs to slightly more verbose or explicit, but equivalent forms (like `a < b < c` => `a < b && b < c`).
    
    Its main advantage is that later stages don't explicitly have to handle syntactic sugar (and some other constructs) that would otherwise need to be processed differently in every stage.

1. Scope Discovery (Julia AST -> SAST)
1. Type Inferrence (SAST -> TAST)
1. Language Transformations (TAST -> IR AST)
1. Code generation