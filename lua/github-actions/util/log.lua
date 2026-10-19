local config = require("github-actions.config")

local log = {}

--- Shows a debug message, only when `debug = true` is set in the config.
---
---@param scope string Where the message comes from.
---@param msg string The message, already formatted.
---@private
function log.debug(scope, msg)
    if not config.options.debug then
        return
    end

    vim.notify(
        string.format("[github-actions.nvim@%s] %s", scope, msg),
        vim.log.levels.DEBUG,
        { title = "github-actions.nvim" }
    )
end

return log
