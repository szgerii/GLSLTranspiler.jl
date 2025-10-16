export BlockConflictStrategy

@enum BlockConflictStrategy BCS_Overwrite BCS_Ignore BCS_IgnoreWarning BCS_OverwriteWarning BCS_Error

@kwdef mutable struct TranspilerConfig
    # ================
    # General settings
    # ================

    # whether to replace 64-bit float literals (like 2.0) with their 32-bit counterpart (2.0f0)
    literals_as_f32::Bool = true

    # =============================
    # GLSL/OpenGL-specific settings
    # =============================

    # whether to make function calls use their JuliaGLM library implementations whenever possible
    # e.g. automatically turn min(a,b) into JuliaGLM.min(a, b) 
    gl_rewrite_to_glm::Bool = true
    
    # control shader header versioning through these two
    gl_version::Unsigned = 330
    gl_core::Bool        = true

    # whether transpile-time evaluation happens for const assignment rhs
    # e.g. `@constant global x = 2 + 1` will be automatically converted to `const int x = 3`
    # this supports any time of expression on the rhs, as long as it returns a literal value
    # (and can be evaluated at transpile-time)
    gl_const_eval::Bool = true

    # determines if the transpiler overwrites previously stored interface blocks with conflicting
    # block names when a new interface block is inserted into __INTERFACE_BLOCKS.
    #
    # Its type is the BlockConflictStrategy enum, which can be one of the following:
    # BCS_Error (default): 
    #   Throw an error if a block is being registered with a pre-existing block name
    # BCS_Overwrite:
    #   Overwrite the previous interface block that has the same block name silently
    # BCS_Ignore:
    #   Ignore any attempted inserts that target a previously existing block name silently
    # BCS_OverwriteWarning:
    #   Overwrite the previous interface block that has the same block name, but print a warning to the console
    # BCS_IgnoreWarning:
    #   Ignore any attempted inserts that target a previously existing block name, but print a warning to the console
    #
    # NOTE: this has no effect if you're constructing an InterfaceBlock object, without inserting
    # it into the global __INTERFACE_BLOCKS collection
    gl_block_conflict::BlockConflictStrategy = BCS_Error
end

global transpiler_config::TranspilerConfig = TranspilerConfig()
