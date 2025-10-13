local log = require("github-actions.util.log")

local GithubActions = {}

--- GithubActions configuration with its default values.
---
---@type table
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
GithubActions.options = {
    -- Prints useful logs about what event are triggered, and reasons actions are executed.
    debug = false,
    -- UI method to use for displaying CI status (currently only "telescope" is supported)
    ui_method = "telescope",
    -- Maximum number of runs to fetch from GitHub Actions
    telescope_limit = 20,
}

---@private
local defaults = vim.deepcopy(GithubActions.options)

--- Defaults GithubActions options by merging user provided options with the default plugin values.
---
---@param options table Module config table. See |GithubActions.options|.
---
---@private
function GithubActions.defaults(options)
    GithubActions.options =
        vim.deepcopy(vim.tbl_deep_extend("keep", options or {}, defaults or {}))

    -- let your user know that they provided a wrong value, this is reported when your plugin is executed.
    assert(
        type(GithubActions.options.debug) == "boolean",
        "`debug` must be a boolean (`true` or `false`)."
    )

    assert(
        type(GithubActions.options.ui_method) == "string",
        "`ui_method` must be a string."
    )

    assert(
        type(GithubActions.options.telescope_limit) == "number",
        "`telescope_limit` must be a number."
    )

    return GithubActions.options
end

--- Define your github-actions setup.
---
---@param options table Module config table. See |GithubActions.options|.
---
---@usage `require("github-actions").setup()` (add `{}` with your |GithubActions.options| table)
function GithubActions.setup(options)
    GithubActions.options = GithubActions.defaults(options or {})

    log.warn_deprecation(GithubActions.options)

    return GithubActions.options
end

return GithubActions
