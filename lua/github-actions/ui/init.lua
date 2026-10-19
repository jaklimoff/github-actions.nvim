local config = require("github-actions.config")
local log = require("github-actions.util.log")

local ui = {}

--- Show GitHub Actions CI status using the configured UI method.
---
---@param opts? table Options to pass to the UI.
---@private
function ui.show_ci_status(opts)
    opts = opts or {}

    local ui_method = opts.ui_method or config.options.ui_method

    log.debug("ui.show_ci_status", "Using UI method: " .. ui_method)

    if ui_method == "telescope" then
        require("github-actions.ui.telescope").show_ci_status(opts)
    else
        vim.notify("Unknown UI method: " .. ui_method, vim.log.levels.ERROR)
    end
end

return ui
