local api = require("github-actions.api")
local log = require("github-actions.util.log")

local telescope = {}

---@class RunStatusInfo
---@field icon string
---@field text string
---@field highlight string

---Get formatted status information for a run
---@param run GitHubRun
---@return RunStatusInfo
local function get_status_info(run)
  local status_icon = "●"
  local status_text = run.status
  local highlight = "Normal"

  if run.status == "completed" then
    if run.conclusion == "success" then
      status_icon = "✓"
      status_text = "✓ success"
      highlight = "DiagnosticOk"
    elseif run.conclusion == "failure" then
      status_icon = "✗"
      status_text = "✗ failure"
      highlight = "DiagnosticError"
    elseif run.conclusion == "cancelled" then
      status_icon = "○"
      status_text = "○ cancelled"
      highlight = "DiagnosticWarn"
    else
      status_icon = "○"
      status_text = "○ " .. (run.conclusion or "completed")
      highlight = "DiagnosticInfo"
    end
  elseif run.status == "in_progress" then
    status_icon = "⟳"
    status_text = "⟳ running"
    highlight = "DiagnosticWarn"
  elseif run.status == "queued" then
    status_icon = "⋯"
    status_text = "⋯ queued"
    highlight = "DiagnosticInfo"
  end

  return {
    icon = status_icon,
    text = status_text,
    highlight = highlight,
  }
end

---Create a telescope entry display formatter
---@return table displayer Telescope entry display formatter
local function create_displayer()
  local entry_display = require("telescope.pickers.entry_display")
  return entry_display.create({
    separator = " ",
    items = {
      { width = 12 }, -- status with icon
      { width = 30 }, -- workflow name
      { remaining = true }, -- title
    },
  })
end

---Create entry maker for telescope picker
---@param displayer table The display formatter
---@return function entry_maker Function that creates telescope entries
local function create_entry_maker(displayer)
  return function(entry)
    -- Handle loading state
    if entry.is_loading then
      return {
        value = entry,
        ordinal = "loading",
        display = function()
          return displayer({
            { "⟳ Loading...", "DiagnosticWarn" },
            { "", "" },
            { "", "" },
          })
        end,
      }
    end

    -- Handle error state
    if entry.is_error then
      return {
        value = entry,
        ordinal = "error",
        display = function()
          return displayer({
            { "✗ Error", "DiagnosticError" },
            { "Failed to fetch runs", "DiagnosticError" },
            { "", "" },
          })
        end,
      }
    end

    -- Handle actual run entries
    local status_info = get_status_info(entry.value)
    return {
      value = entry.value,
      ordinal = entry.value.name .. " " .. (entry.value.displayTitle or "") .. " " .. entry.value.status,
      display = function(tbl)
        return displayer({
          { status_info.text, status_info.highlight },
          { tbl.value.name, "TelescopeResultsIdentifier" },
          { tbl.value.displayTitle or "", "TelescopeResultsComment" },
        })
      end,
      status_info = status_info,
    }
  end
end

---Create telescope previewer for run details
---@param branch string Current branch name
---@return table previewer Telescope previewer
local function create_previewer(branch)
  local previewers = require("telescope.previewers")
  return previewers.new_buffer_previewer({
    title = "Run Details",
    define_preview = function(self, entry)
      -- Handle loading state
      if entry.value and entry.value.is_loading then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "Loading GitHub CI runs..." })
        return
      end

      ---@type GitHubRun
      local run = entry.value
      local status_info = get_status_info(run)

      local lines = {
        "Workflow: " .. run.name,
        "Title: " .. (run.displayTitle or "N/A"),
        "Branch: " .. (run.headBranch or branch),
        "Event: " .. (run.event or "N/A"),
        "",
        "Status: " .. status_info.text,
        "Conclusion: " .. (run.conclusion or "pending"),
        "",
        "Run ID: " .. run.databaseId,
        "Created: " .. (run.createdAt or "N/A"),
        "",
        "Actions:",
        "  <CR>  - View logs",
        "  <C-w> - Watch run",
        "  <C-b> - Open in browser",
      }
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    end,
  })
end

---Setup telescope picker mappings
---@param prompt_bufnr number Telescope prompt buffer number
---@param map function Telescope map function
---@return boolean
local function setup_mappings(prompt_bufnr, map)
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  actions.select_default:replace(function()
    local selection = action_state.get_selected_entry()
    if selection.value.is_loading then
      return
    end
    actions.close(prompt_bufnr)
    api.view_run_logs(selection.value.databaseId)
  end)

  map("i", "<C-w>", function()
    local selection = action_state.get_selected_entry()
    if selection.value.is_loading then
      return
    end
    actions.close(prompt_bufnr)
    api.watch_run(selection.value.databaseId)
  end)

  map("i", "<C-b>", function()
    local selection = action_state.get_selected_entry()
    if selection.value.is_loading then
      return
    end
    actions.close(prompt_bufnr)
    api.open_run_browser(selection.value.databaseId)
  end)

  map("i", "<C-l>", function()
    local selection = action_state.get_selected_entry()
    if selection.value.is_loading then
      return
    end
    actions.close(prompt_bufnr)
    api.view_run_logs(selection.value.databaseId)
  end)

  return true
end

---Show CI status in Telescope picker
---@param opts? table Telescope options
function telescope.show_ci_status(opts)
  opts = opts or {}

  -- Check dependencies
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("telescope.nvim is required but not installed", vim.log.levels.ERROR)
    log.debug("telescope.show_ci_status", "telescope.nvim not found")
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  -- Get config
  local config = _G.GithubActions.config or {}
  local limit = opts.limit or config.telescope_limit or 20

  -- Get current branch
  local branch = api.get_current_branch()
  if not branch then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    log.debug("telescope.show_ci_status", "Not in a git repository")
    return
  end

  log.debug("telescope.show_ci_status", string.format("Opening picker for branch: %s", branch))

  -- Setup display components
  local displayer = create_displayer()
  local entry_maker = create_entry_maker(displayer)

  -- Create picker with loading state
  local picker = pickers.new(opts, {
    prompt_title = "GitHub CI/CD Status - " .. branch,
    finder = finders.new_table({
      results = { { is_loading = true } },
      entry_maker = entry_maker,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = create_previewer(branch),
    attach_mappings = setup_mappings,
  })

  -- Open picker immediately
  picker:find()

  -- Fetch data asynchronously and update picker
  api.fetch_runs_async(branch, limit, function(runs)
    local entries = vim.tbl_map(function(run)
      return { value = run }
    end, runs)

    picker:refresh(
      finders.new_table({
        results = entries,
        entry_maker = entry_maker,
      }),
      opts
    )
  end, function(error_msg)
    vim.notify("Error fetching CI status: " .. error_msg, vim.log.levels.ERROR)
    picker:refresh(
      finders.new_table({
        results = { { is_error = true, message = error_msg } },
        entry_maker = entry_maker,
      }),
      opts
    )
  end)
end

return telescope
