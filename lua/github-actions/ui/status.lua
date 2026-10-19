local status = {}

---@class RunStatusInfo
---@field text string Status label with its icon, e.g. "✓ success".
---@field highlight string Highlight group for the label.

---@private
local conclusions = {
    success = { "✓", "DiagnosticOk" },
    failure = { "✗", "DiagnosticError" },
    timed_out = { "✗", "DiagnosticError" },
    startup_failure = { "✗", "DiagnosticError" },
    cancelled = { "○", "DiagnosticWarn" },
}

--- Treat gh's empty strings as missing values.
---
---@param value string|nil
---@return string|nil
---@private
function status.non_empty(value)
    if value == nil or value == "" or value == vim.NIL then
        return nil
    end

    return value
end

--- Get the status label and highlight for a run.
---
---@param run GitHubRun
---@return RunStatusInfo
---@private
function status.get(run)
    if run.status == "completed" then
        local conclusion = status.non_empty(run.conclusion) or "completed"
        local info = conclusions[conclusion] or { "○", "DiagnosticInfo" }

        return { text = info[1] .. " " .. conclusion, highlight = info[2] }
    end

    if run.status == "in_progress" then
        return { text = "⟳ running", highlight = "DiagnosticWarn" }
    end

    return {
        text = "⋯ " .. (status.non_empty(run.status) or "unknown"),
        highlight = "DiagnosticInfo",
    }
end

return status
