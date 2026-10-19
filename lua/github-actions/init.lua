--- *github-actions* GitHub Actions at your fingertips
---
--- Browse the GitHub Actions runs of the current branch in a Telescope picker,
--- view their logs, watch them live, or open them in the browser.
---
--- Requirements:
--- - GitHub CLI (`gh`), installed and authenticated.
--- - telescope.nvim and plenary.nvim.
---
--- Commands:
--- - `:GithubActionsStatus` opens the picker for the current branch.
---
--- Picker keys:
--- - `<CR>`, `<C-l>` view the run logs in a terminal.
--- - `<C-a>` watch the run live.
--- - `<C-b>` open the run in the browser.

local api = require("github-actions.api")
local config = require("github-actions.config")

local GithubActions = {}

--- Set up the plugin and merge the user options with the defaults.
---
---@param opts table|nil See |GithubActions.options|.
---
---@usage `require("github-actions").setup()` (add `{}` with your |GithubActions.options| table)
function GithubActions.setup(opts)
    config.setup(opts)
end

--- Show GitHub Actions CI status in a picker
---@param opts? table Options to pass to the UI (e.g., { limit = 30 })
function GithubActions.show_ci_status(opts)
    require("github-actions.ui").show_ci_status(opts)
end

--- View a specific GitHub Actions run
---@param run_id number The run ID to view
function GithubActions.view_run(run_id)
    api.view_run(run_id)
end

--- Watch a specific GitHub Actions run
---@param run_id number The run ID to watch
function GithubActions.watch_run(run_id)
    api.watch_run(run_id)
end

--- Open a specific GitHub Actions run in browser
---@param run_id number The run ID to open
function GithubActions.open_run_browser(run_id)
    api.open_run_browser(run_id)
end

return GithubActions
