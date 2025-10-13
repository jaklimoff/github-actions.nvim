local main = require("github-actions.main")
local config = require("github-actions.config")
local ui = require("github-actions.ui")
local api = require("github-actions.api")

local GithubActions = {}

--- Toggle the plugin by calling the `enable`/`disable` methods respectively.
function GithubActions.toggle()
    if _G.GithubActions.config == nil then
        _G.GithubActions.config = config.options
    end

    main.toggle("public_api_toggle")
end

--- Initializes the plugin, sets event listeners and internal state.
function GithubActions.enable(scope)
    if _G.GithubActions.config == nil then
        _G.GithubActions.config = config.options
    end

    main.toggle(scope or "public_api_enable")
end

--- Disables the plugin, clear highlight groups and autocmds, closes side buffers and resets the internal state.
function GithubActions.disable()
    main.toggle("public_api_disable")
end

-- setup GithubActions options and merge them with user provided ones.
function GithubActions.setup(opts)
    _G.GithubActions.config = config.setup(opts)
end

--- Show GitHub Actions CI status in a picker
---@param opts? table Options to pass to the UI (e.g., { limit = 30 })
function GithubActions.show_ci_status(opts)
    ui.show_ci_status(opts)
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

_G.GithubActions = GithubActions

return _G.GithubActions
