local api = require("github-actions.api")
local config = require("github-actions.config")
local log = require("github-actions.util.log")
local status = require("github-actions.ui.status")

local telescope = {}

-- A row shown in place of runs: loading, error, or no runs.
---@class MessageRow
---@field message string Label for the status column.
---@field highlight string
---@field detail string One-line text for the title column.
---@field preview string Text for the preview window.

--- Create a placeholder row.
---
---@param message string
---@param highlight string
---@param preview string
---@return MessageRow
---@private
local function message_row(message, highlight, preview)
    return {
        message = message,
        highlight = highlight,
        detail = (preview:gsub("%s*\n%s*", " ")),
        preview = preview,
    }
end

--- Create the entry display formatter.
---
---@return function
---@private
local function create_displayer()
    return require("telescope.pickers.entry_display").create({
        separator = " ",
        items = {
            { width = 12 }, -- status with icon
            { width = 30 }, -- workflow name
            { remaining = true }, -- title
        },
    })
end

--- Create the entry maker for runs and placeholder rows.
---
---@param displayer function
---@return function
---@private
local function create_entry_maker(displayer)
    return function(item)
        if item.message then
            return {
                value = item,
                ordinal = item.message .. " " .. item.detail,
                display = function()
                    return displayer({
                        { item.message, item.highlight },
                        "",
                        { item.detail, item.highlight },
                    })
                end,
            }
        end

        ---@type GitHubRun
        local run = item
        local info = status.get(run)
        local name = status.non_empty(run.name) or ""
        local title = status.non_empty(run.displayTitle) or ""

        return {
            value = run,
            -- Include the status label so typing "failure" or "running" filters runs.
            ordinal = table.concat({
                info.text,
                name,
                title,
                status.non_empty(run.event) or "",
            }, " "),
            display = function()
                return displayer({
                    { info.text, info.highlight },
                    { name, "TelescopeResultsIdentifier" },
                    { title, "TelescopeResultsComment" },
                })
            end,
        }
    end
end

--- Lines describing a run, for the preview window.
---
---@param run GitHubRun
---@param branch string
---@return string[]
---@private
local function run_details(run, branch)
    local function field(value)
        return status.non_empty(value) or "N/A"
    end

    return {
        "Workflow: " .. field(run.name),
        "Title: " .. field(run.displayTitle),
        "Branch: " .. (status.non_empty(run.headBranch) or branch),
        "Event: " .. field(run.event),
        "",
        "Status: " .. status.get(run).text,
        "Conclusion: " .. (status.non_empty(run.conclusion) or "pending"),
        "",
        "Run ID: " .. tostring(run.databaseId),
        "Created: " .. field(run.createdAt),
        "",
        "Actions:",
        "  <CR>  - View logs",
        "  <C-a> - Watch run",
        "  <C-b> - Open in browser",
    }
end

--- Create the previewer for run details.
---
---@param branch string
---@return table
---@private
local function create_previewer(branch)
    return require("telescope.previewers").new_buffer_previewer({
        title = "Run Details",
        define_preview = function(self, entry)
            local item = entry.value
            local lines = item.message and vim.split(item.preview, "\n")
                or run_details(item, branch)
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        end,
    })
end

--- Create the picker key mappings.
---
---@param cwd string Directory to run gh in.
---@return function attach_mappings
---@private
local function create_mappings(cwd)
    return function(prompt_bufnr, map)
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        -- Wrap an api function so it runs on the selected run, if there is one.
        local function on_run(fn)
            return function()
                local entry = action_state.get_selected_entry()
                if not entry or entry.value.message then
                    return
                end

                actions.close(prompt_bufnr)
                fn(entry.value.databaseId, cwd)
            end
        end

        actions.select_default:replace(on_run(api.view_run_logs))

        for _, mode in ipairs({ "i", "n" }) do
            map(mode, "<C-l>", on_run(api.view_run_logs))
            map(mode, "<C-a>", on_run(api.watch_run))
            map(mode, "<C-b>", on_run(api.open_run_browser))
        end

        return true
    end
end

--- Show CI status in a Telescope picker.
---
---@param opts? table Telescope options, plus `limit`.
---@private
function telescope.show_ci_status(opts)
    opts = opts or {}

    local ok, pickers = pcall(require, "telescope.pickers")
    if not ok then
        vim.notify("telescope.nvim is required but not installed", vim.log.levels.ERROR)
        return
    end

    local finders = require("telescope.finders")
    local conf = require("telescope.config").values

    local limit = opts.limit or config.options.telescope_limit
    local cwd = api.get_cwd()

    local branch, err = api.get_current_branch(cwd)
    if not branch then
        vim.notify(err, vim.log.levels.ERROR)
        return
    end

    log.debug("telescope.show_ci_status", "Opening picker for branch: " .. branch)

    local entry_maker = create_entry_maker(create_displayer())

    local function finder(results)
        return finders.new_table({ results = results, entry_maker = entry_maker })
    end

    local picker = pickers.new(opts, {
        prompt_title = "GitHub CI/CD Status - " .. branch,
        finder = finder({
            message_row("⟳ Loading...", "DiagnosticWarn", "Loading GitHub Actions runs..."),
        }),
        sorter = conf.generic_sorter(opts),
        previewer = create_previewer(branch),
        attach_mappings = create_mappings(cwd),
    })

    picker:find()

    -- The picker may be closed before the runs arrive.
    local function is_open()
        return picker.prompt_bufnr ~= nil and vim.api.nvim_buf_is_valid(picker.prompt_bufnr)
    end

    api.fetch_runs_async({ branch = branch, limit = limit, cwd = cwd }, function(runs)
        if not is_open() then
            return
        end

        if #runs == 0 then
            picker:refresh(finder({
                message_row("○ No runs", "DiagnosticInfo", "No runs found for branch " .. branch),
            }))
            return
        end

        picker:refresh(finder(runs))
    end, function(fetch_err)
        if not is_open() then
            vim.notify("Error fetching CI status: " .. fetch_err, vim.log.levels.ERROR)
            return
        end

        picker:refresh(finder({ message_row("✗ Error", "DiagnosticError", fetch_err) }))
    end)
end

return telescope
