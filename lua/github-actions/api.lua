local log = require("github-actions.util.log")

local api = {}

---@alias RunStatus "completed"|"in_progress"|"queued"|"waiting"
---@alias RunConclusion "success"|"failure"|"cancelled"|"skipped"|"timed_out"|"action_required"|"neutral"|"stale"

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

---Get current git branch
---@return string|nil branch The current git branch, or nil if not in a git repository
function api.get_current_branch()
  local handle = io.popen("git branch --show-current 2>/dev/null")
  if not handle then
    log.debug("api.get_current_branch", "Failed to execute git command")
    return nil
  end

  local result = handle:read("*a")
  handle:close()

  if result then
    result = result:gsub("\n", "")
    if result ~= "" then
      return result
    end
  end

  return nil
end

---Fetch GitHub CI/CD run items asynchronously
---@param branch string The branch to fetch runs for
---@param limit number Maximum number of runs to fetch
---@param on_success function(runs: GitHubRun[]) Callback for successful fetch
---@param on_error function(error: string) Callback for errors
function api.fetch_runs_async(branch, limit, on_success, on_error)
  local ok, Job = pcall(require, "plenary.job")
  if not ok then
    local error_msg = "plenary.nvim is required but not installed"
    log.debug("api.fetch_runs_async", error_msg)
    on_error(error_msg)
    return
  end

  log.debug("api.fetch_runs_async", string.format("Fetching runs for branch: %s, limit: %d", branch, limit))

  Job:new({
    command = "gh",
    args = {
      "run",
      "list",
      "--branch",
      branch,
      "--limit",
      tostring(limit),
      "--json",
      "status,conclusion,name,displayTitle,createdAt,databaseId,headBranch,event,workflowName",
    },
    on_exit = vim.schedule_wrap(function(job, return_code)
      if return_code ~= 0 then
        local error_msg = table.concat(job:stderr_result(), "\n")
        log.debug("api.fetch_runs_async", string.format("Failed to fetch runs: %s", error_msg))
        on_error(error_msg)
        return
      end

      local output = table.concat(job:result(), "\n")
      local decode_ok, runs = pcall(vim.json.decode, output)

      if not decode_ok or not runs or #runs == 0 then
        local error_msg = "No CI runs found"
        log.debug("api.fetch_runs_async", error_msg)
        on_error(error_msg)
        return
      end

      log.debug("api.fetch_runs_async", string.format("Successfully fetched %d runs", #runs))
      on_success(runs)
    end),
  }):start()
end

---View a specific run by ID
---@param run_id number The run ID to view
function api.view_run(run_id)
  log.debug("api.view_run", string.format("Opening run %d", run_id))
  vim.cmd(string.format("terminal gh run view %s", run_id))
end

---Watch a specific run by ID
---@param run_id number The run ID to watch
function api.watch_run(run_id)
  log.debug("api.watch_run", string.format("Watching run %d", run_id))
  vim.cmd(string.format("terminal gh run watch %s", run_id))
end

---View run logs in terminal
---@param run_id number The run ID to view logs for
function api.view_run_logs(run_id)
  log.debug("api.view_run_logs", string.format("Opening logs for run %d", run_id))
  vim.cmd(string.format("terminal gh run view %s --log", run_id))
end

---Open a specific run in browser
---@param run_id number The run ID to open
function api.open_run_browser(run_id)
  log.debug("api.open_run_browser", string.format("Opening run %d in browser", run_id))
  vim.fn.system(string.format("gh run view %s --web", run_id))
  vim.notify("Opening run in browser...", vim.log.levels.INFO)
end

return api
