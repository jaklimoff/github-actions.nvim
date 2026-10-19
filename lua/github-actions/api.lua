local log = require("github-actions.util.log")

local api = {}

---@alias RunStatus "completed"|"in_progress"|"queued"|"waiting"|"requested"|"pending"
---@alias RunConclusion "success"|"failure"|"cancelled"|"skipped"|"timed_out"|"action_required"|"neutral"|"stale"|"startup_failure"|""

---@class GitHubRun
---@field status RunStatus
---@field conclusion RunConclusion|nil
---@field name string
---@field displayTitle string|nil
---@field createdAt string
---@field databaseId number
---@field headBranch string
---@field event string
---@field workflowName string

local RUN_FIELDS =
    "status,conclusion,name,displayTitle,createdAt,databaseId,headBranch,event,workflowName"

--- Directory to run git and gh in: the current file's folder, or the working directory.
---
---@return string
---@private
function api.get_cwd()
    local name = vim.api.nvim_buf_get_name(0)
    if vim.bo.buftype == "" and name ~= "" then
        local dir = vim.fn.fnamemodify(name, ":p:h")
        if vim.fn.isdirectory(dir) == 1 then
            return dir
        end
    end

    return vim.fn.getcwd()
end

--- Get the current git branch.
---
---@param cwd string|nil Directory inside the repository. Defaults to |api.get_cwd()|.
---@return string|nil branch The current branch, or nil on failure.
---@return string|nil err Why there is no branch.
---@private
function api.get_current_branch(cwd)
    local lines =
        vim.fn.systemlist({ "git", "-C", cwd or api.get_cwd(), "branch", "--show-current" })
    if vim.v.shell_error ~= 0 then
        log.debug("api.get_current_branch", "git failed: " .. table.concat(lines, " "))
        return nil, "Not in a git repository"
    end

    local branch = lines[1]
    if not branch or branch == "" then
        return nil, "Detached HEAD: check out a branch to see its runs"
    end

    return branch
end

--- Fetch GitHub Actions runs asynchronously.
---
---@param opts { branch: string, limit: number, cwd: string|nil }
---@param on_success fun(runs: GitHubRun[]) Called with the runs (possibly empty).
---@param on_error fun(err: string) Called with an error message.
---@private
function api.fetch_runs_async(opts, on_success, on_error)
    local ok, Job = pcall(require, "plenary.job")
    if not ok then
        on_error("plenary.nvim is required but not installed")
        return
    end

    if vim.fn.executable("gh") == 0 then
        on_error("GitHub CLI (gh) was not found in PATH")
        return
    end

    log.debug(
        "api.fetch_runs_async",
        string.format("Fetching runs for branch: %s, limit: %d", opts.branch, opts.limit)
    )

    Job
        :new({
            command = "gh",
            args = {
                "run",
                "list",
                "--branch",
                opts.branch,
                "--limit",
                tostring(opts.limit),
                "--json",
                RUN_FIELDS,
            },
            cwd = opts.cwd,
            on_exit = vim.schedule_wrap(function(job, return_code)
                if return_code ~= 0 then
                    local err = vim.trim(table.concat(job:stderr_result(), "\n"))
                    log.debug("api.fetch_runs_async", "Failed to fetch runs: " .. err)
                    on_error(err ~= "" and err or "gh exited with code " .. return_code)
                    return
                end

                local decode_ok, runs = pcall(vim.json.decode, table.concat(job:result(), "\n"))
                if not decode_ok or type(runs) ~= "table" then
                    log.debug("api.fetch_runs_async", "Could not parse gh output")
                    on_error("Could not parse the output of `gh run list`")
                    return
                end

                log.debug("api.fetch_runs_async", string.format("Fetched %d runs", #runs))
                on_success(runs)
            end),
        })
        :start()
end

--- Run a command in a terminal buffer in the current window.
---
---@param cmd string[]
---@param cwd string|nil
---@private
local function open_terminal(cmd, cwd)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, buf)

    if vim.fn.has("nvim-0.11") == 1 then
        vim.fn.jobstart(cmd, { term = true, cwd = cwd })
    else
        vim.fn.termopen(cmd, { cwd = cwd })
    end
end

--- View a specific run by ID.
---
---@param run_id number The run ID to view.
---@param cwd string|nil Directory to run gh in.
---@private
function api.view_run(run_id, cwd)
    log.debug("api.view_run", "Opening run " .. run_id)
    open_terminal({ "gh", "run", "view", tostring(run_id) }, cwd)
end

--- Watch a specific run by ID.
---
---@param run_id number The run ID to watch.
---@param cwd string|nil Directory to run gh in.
---@private
function api.watch_run(run_id, cwd)
    log.debug("api.watch_run", "Watching run " .. run_id)
    open_terminal({ "gh", "run", "watch", tostring(run_id) }, cwd)
end

--- View run logs in a terminal.
---
---@param run_id number The run ID to view logs for.
---@param cwd string|nil Directory to run gh in.
---@private
function api.view_run_logs(run_id, cwd)
    log.debug("api.view_run_logs", "Opening logs for run " .. run_id)
    open_terminal({ "gh", "run", "view", tostring(run_id), "--log" }, cwd)
end

--- Open a specific run in the browser.
---
---@param run_id number The run ID to open.
---@param cwd string|nil Directory to run gh in.
---@private
function api.open_run_browser(run_id, cwd)
    log.debug("api.open_run_browser", "Opening run " .. run_id .. " in browser")

    if vim.fn.executable("gh") == 0 then
        vim.notify("GitHub CLI (gh) was not found in PATH", vim.log.levels.ERROR)
        return
    end

    local stderr = ""
    vim.fn.jobstart({ "gh", "run", "view", tostring(run_id), "--web" }, {
        cwd = cwd,
        stderr_buffered = true,
        on_stderr = function(_, data)
            stderr = vim.trim(table.concat(data or {}, "\n"))
        end,
        on_exit = function(_, code)
            if code ~= 0 then
                vim.notify("Could not open run in browser: " .. stderr, vim.log.levels.ERROR)
            end
        end,
    })

    vim.notify("Opening run in browser...", vim.log.levels.INFO)
end

return api
