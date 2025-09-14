# Transpiler.jl

This project is a general shader transpiler for the Julia language. Currently it only supports Julia -> GLSL transpilation, but a pipeline for languages like HLSL can be easily created in the future.

It was created as part of my 2025 summer internship at ELTE.

## Usage

The transpiler exists as a completely independent package that can be injected into any project. Its main API consists mostly of the run_pipeline found in the base Transpiler module. It can be used in the following way:

```julia
using Transpiler
using JuliaGLM

input_def = :(
    function my_julia_shader(#= ... =#)
        # ...
    end
)

# Arguments are:
#   - the pipeline to run
#   - the fn def to run it on
#   - the module to use as a "Julia context"
(gen_def, gen_code, gen_helpers) = run_pipeline(Transpiler.GLSL.glsl_pipeline, input_def, Main)

# or:
code = @transpile(
    Transpiler.GLSL.glsl_pipeline,
    :(
        function my_julia_shader(#= ... =#)
            # ...
        end
    ),
    Verbose # optional logging level (Silent [default], Progress, Verbose)
)
```

The run pipeline will output three things as a Tuple:
1. **Expr** <br>
    The transformed function definition that can be defined in Julia (stripped from macros and potentially transformed to match the semantics of the generated code better)
1. **Any** <br>
    The generated shader code (including potential helper function definitions as well) <br>
    NOTE: The GLSL pipeline outputs a String here (which is the recommended output type), but pipelines are free to return whatever type they want here
1. **Vector{Tuple{Expr,Any}}** <br>
    A list of generated helper functions, in the same structure as the above two outputs (so Vector{Tuple{Expr,String}} for the GLSL pipeline). The first tuple elems will be the generated defs and the second ones will be the generated code. <br>
    It is simply an empty Vector if no helper functions are used in the input code.

The `@transpile` macro is provided as a convenience for general shader transpilation. It accepts the pipeline, the base code and an optional logging level as its input and will only return the generated final shader code. It handles the function definitions automatically by eval-ing the generated definitions into the calling module. <br>
NOTE: This means that if you want to use a different module for transpilation than the current one, you have to use the first approach, or eval the @transpile macro call in the desired module (although the second approach is discouraged because it could easily lead to macro hygiene issues if not handled carefully).

## Project Structure

### Pipelines and stages

The transpilation process happens according to pipelines, which are in turn made up of a sequence of stages. Stages usually perform some kind of transformation on the AST and output either the same kind of tree they received as input or a new kind. Subsequent stages in pipelines must pay attention to matching their input/output interface, so that the pipeline runner can just pass the previous stage's output as input to the next one without having to perform additional configurations.

### Core Pipeline

The core pipeline is made up of four stages. This can serve as a base for any general shader pipeline. It's made up of the following stages:

1. Preprocessor
1. Scope Discovery
1. Symbol Resolution
1. Type Inference

Note that this "core pipeline" only exists on a conceptual level, there's no representation of it in the package. However, if you look into the GLSL pipeline, you will find these four stages in this exact execution order.

The goal of the core pipeline is to take a standard Julia AST for a function definition and output a typed AST that has

1. Type information about variables and function calls
1. Type information about the function itself (i.e. return type)
1. Exact scope boundaries and their types (e.g. hard, soft, module-level, etc.)
1. Uniquely named symbols

This can be expanded by prepending or appending stages that prepare or finish the transpilation process respectively. It's also possible to insert stages between any two core pipeline stages, although that requires some familiarity with their structure, so that the input/output interface chain remains intact.

See my summary documentation for further information about these stages.

### GLSL Pipeline

The GLSL transpilation pipeline extends the core pipeline with a couple of stages:

1. GLSL preprocessor
1. *Core pipeline* (see above)
1. IR transformation
1. Code generation

The GLSL preprocessor is only used for transforming qualifier macros into a processable AST-form.

The IR transformation is for generating a GLSL-like AST structure from the typed AST output of the core pipeline.

Finally, the code generation stage is where the actual shader code gets constructed.

## File Structure

### Package code

The main module is defined in *src/Transpiler.jl*, but this generally only imports generic *includes.jl* files from the submodule directories. Those are in turn responsible for defining the structure/inclusion order of their respective submodules.

The *src/pipeline_runner.jl* file contains the functions and convenience macros for generic transpilation. More specific macros may be defined, like the ```@glsl``` macro coming from *src/glsl/glsl_pipeline.jl*.

### Stages

Stages usually perform a full traversal on the current state of the AST. They do this through the *Tagger.jl* pkg, which was developed as a utility for this project. See the *README.md* file of that project to get an understanding of its logic, structure and internal working.

Each stage is structured in roughly the same manner:

1. Define the tree type(s) for the output of the stage, if needed
1. Define a context for the traversal, if needed (e.g. a unique symbol storage for Symbol Resolution)
1. Define a set of Tagger rules and tags for traversal
1. Define a (usually lightweight) traversal function responsible for overseeing the traversal and applying its transformations
1. Define a more complex transformation function, whose job is to transform a single node into the state it needs to be in for the output.

This separated traversal/transformation logic keeps the code for transforming nodes and actually applying those transformations into the tree mostly detached. This means that the transformation methods can be made more humanly readable, as they only worry about performing transformations locally, not in a tree-wide context.

Stages for the core pipeline can be found in the *src/core/stages* directory, while stages for the GLSL pipeline can be found in *src/glsl/stages*.

The GLSL pipeline itself is defined in *src/glsl/glsl_pipeline.jl*. It may be useful to export this from Transpiler.GLSL, but I wanted to keep namespace pollution to a minimum for now.

### Utils

In the *src/utils/* directory you will find some general utility functions for both general Julia stuff (precompilation, type inspection, the @exported macro) and for more specific AST traversal related things. <br>
These are available to use anywhere in the Transpiler code, just make sure you're importing and using the Transpiler.Utils submodule.

### Examples

There are a couple of example Julia shaders in the *examples/* directory, which should be enough to showcase the semantics of writing a GLSL shader recognized by the transpiler.

### Misc

These are snippets that were (or will be) useful during development, but have no actual use case when using the package outside of that.

## Known Issues

- **Precompilation:** <br>
The uses lots of generic traversal and transformation functions for performing passes on the AST. This allows dynamic traversal behavior through Julia's multiple dispatch pattern, but it also means that a lot of methods need to be compiled for each traversal stage. Most of these have been marked to be precompiled for each possible traversal route, but there are still some things missing, leading to noticably slower performance on first transpilations. As a consequence, however, the precompile time has also significantly started to increase. I tried to find a balance between precompilation time and first run performance, but it can be tuned further. <br>
As far as I could tell, this is a recurring issue with package development in Julia, and while there are options available for both decreasing compile/precompile times and TTFX, it needs a relatively deep understanding of some compiler internals. Conversations and write ups like [this issue from DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl/issues/786) would probably be a good starting place for this "research". <br>
At this point, it may be a better approach to rewrite the traversal logic all together to not make use of Julia's multiple dispatch system, but that would involve a lot of code restructing, though. The reason I generally wanted to avoid this is because the code itself performs well (or at least fine for larger shaders), once everything it needs has been compiled by Julia.

- **Forward Declarations:** <br> 
The current forward-declaration system for unique symbols may lead to optimization-loss from the GLSL compiler in some cases. A new system should be implemented, which determines what's the actual position in the code where the declarations are needed. This is a trickier problem than it may seem at first glance, because of Julia's lenient declaration/scoping rules.

- **Function Definitions:** <br>
The transpiler right now only supports function definitions that are written in the following syntax: <br>
    ```julia
    function shader_fn(#= params ... =#)
        # body ...
    end
    ```

    This means inline function definitions, do block, lambda functions and other syntax like that is not supported. These could be rewritten to use the explicit syntax with the ```function``` keyword (as showcased above) before the transpilation process starts, this way not even having to modify the transpiler process itself, only its API. <br>
    Some work has been done to start this process (see *src/misc/do_parser.jl*), but I didn't deem it high-priority enough to focus on this during the last few weeks of the internship (while complete transpilation stages lacked critical functionality).

- **Error Handling:** <br>
    The transpiler simply throws **ErrorException**s when encountering an error that makes the transpilation impossible. For errors when an assumption has been made about the Julia AST structure that doesn't hold for the current tree, it throws an **AssertionError**. <br>
    These errors unfortunately don't contain much data about the source, like file and line number of the problematic node, they only print a flat representation of it, to provide some help. Using the LineNumberNode-s inside the source AST and the global pipeline context, it would be possible to make these error messages much nicer. The error handling would also really benefit from having custom error types. <br>
    The reason these features have been omitted is that the traversals happen on different kinds of tree structures during each stage (some of which don't even support LineNumberNode-s), so first some kind of universal interface would have to be introduced for tracking file/line num information.
