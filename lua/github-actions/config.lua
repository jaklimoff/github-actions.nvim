local GithubActions = {}

--- GithubActions configuration with its default values.
---
---@type table
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
GithubActions.options = {
    -- Show debug messages about what the plugin is doing.
    debug = false,
    -- UI used to display CI status (only "telescope" is supported for now).
    ui_method = "telescope",
    -- Maximum number of runs to fetch from GitHub Actions.
    telescope_limit = 20,
}

---@private
local defaults = vim.deepcopy(GithubActions.options)

---@private
local ui_methods = { telescope = true }

--- Merge user options with the defaults and validate them.
---
---@param options table|nil Module config table. See |GithubActions.options|.
---@private
function GithubActions.setup(options)
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(defaults), options or {})

    assert(type(merged.debug) == "boolean", "`debug` must be a boolean (`true` or `false`).")
    assert(
        ui_methods[merged.ui_method],
        string.format(
            "`ui_method` must be one of: %s.",
            table.concat(vim.tbl_keys(ui_methods), ", ")
        )
    )
    assert(
        type(merged.telescope_limit) == "number" and merged.telescope_limit > 0,
        "`telescope_limit` must be a positive number."
    )

    GithubActions.options = merged

    return merged
end

return GithubActions
