export PipelineLogger

using Logging

struct PipelineLogger <: AbstractLogger
    min_level::LogLevel
end

function Logging.shouldlog(logger::PipelineLogger, level, _, _, _)
    return level >= logger.min_level
end

function Logging.min_enabled_level(logger::PipelineLogger)
    return logger.min_level
end

function Logging.handle_message(logger::PipelineLogger, level, message, _module, group, id, file, line; kwargs...)
    println(message)
end
