local log = require("github-actions.util.log")

local ui = {}

---Show GitHub Actions CI status using configured UI method
---@param opts? table Options to pass to the UI
function ui.show_ci_status(opts)
  opts = opts or {}

  local config = _G.GithubActions.config or {}
  local ui_method = opts.ui_method or config.ui_method or "telescope"

  log.debug("ui.show_ci_status", string.format("Using UI method: %s", ui_method))

  if ui_method == "telescope" then
    local telescope_ui = require("github-actions.ui.telescope")
    telescope_ui.show_ci_status(opts)
  else
    vim.notify(string.format("Unknown UI method: %s", ui_method), vim.log.levels.ERROR)
    log.debug("ui.show_ci_status", string.format("Unknown UI method: %s", ui_method))
  end
end

return ui
