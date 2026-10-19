local Helpers = dofile("tests/helpers.lua")

-- See https://github.com/echasnovski/mini.nvim/blob/main/lua/mini/test.lua for more documentation

local child = Helpers.new_child_neovim()
local eq = Helpers.expect.equality

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            -- Record notifications instead of showing them.
            child.lua([[
                _G.notified = {}
                vim.notify = function(msg, level) table.insert(_G.notified, { msg = msg, level = level }) end
            ]])
        end,
        post_once = child.stop,
    },
})

T["setup()"] = MiniTest.new_set()

T["setup()"]["exposes public methods and default options"] = function()
    child.lua([[require('github-actions').setup()]])

    for _, name in ipairs({ "setup", "show_ci_status", "view_run", "watch_run", "open_run_browser" }) do
        Helpers.expect.global_type(child, "require('github-actions')." .. name, "function")
    end

    Helpers.expect.config(child, "debug", false)
    Helpers.expect.config(child, "ui_method", "telescope")
    Helpers.expect.config(child, "telescope_limit", 20)
end

T["setup()"]["overrides default values"] = function()
    child.lua([[require('github-actions').setup({ debug = true, telescope_limit = 5 })]])

    Helpers.expect.config(child, "debug", true)
    Helpers.expect.config(child, "telescope_limit", 5)
end

T["setup()"]["rejects invalid values"] = function()
    for _, opts in ipairs({ "{ debug = 1 }", "{ ui_method = 'fzf' }", "{ telescope_limit = 0 }" }) do
        eq(child.lua_get("pcall(require('github-actions').setup, " .. opts .. ")"), false)
    end
end

T["setup()"]["registers the user command"] = function()
    eq(child.fn.exists(":GithubActionsStatus"), 2)
end

T["log"] = MiniTest.new_set()

T["log"]["is silent without setup()"] = function()
    child.lua([[require('github-actions.util.log').debug('test', 'hello')]])
    eq(child.lua_get("#_G.notified"), 0)
end

T["log"]["shows debug messages when enabled"] = function()
    child.lua([[
        require('github-actions').setup({ debug = true })
        require('github-actions.util.log').debug('test', 'HTTP 404 %2F done')
    ]])
    eq(child.lua_get("_G.notified[1].msg"), "[github-actions.nvim@test] HTTP 404 %2F done")
end

T["status"] = MiniTest.new_set({
    parametrize = {
        { { status = "completed", conclusion = "success" }, "✓ success", "DiagnosticOk" },
        { { status = "completed", conclusion = "failure" }, "✗ failure", "DiagnosticError" },
        { { status = "completed", conclusion = "cancelled" }, "○ cancelled", "DiagnosticWarn" },
        { { status = "completed", conclusion = "skipped" }, "○ skipped", "DiagnosticInfo" },
        { { status = "completed", conclusion = "" }, "○ completed", "DiagnosticInfo" },
        { { status = "in_progress", conclusion = "" }, "⟳ running", "DiagnosticWarn" },
        { { status = "queued", conclusion = "" }, "⋯ queued", "DiagnosticInfo" },
        { { status = "waiting" }, "⋯ waiting", "DiagnosticInfo" },
    },
})

T["status"]["labels runs"] = function(run, text, highlight)
    local info = child.lua_get("require('github-actions.ui.status').get(...)", { run })
    eq(info, { text = text, highlight = highlight })
end

T["get_current_branch()"] = MiniTest.new_set()

T["get_current_branch()"]["returns the branch of a repository"] = function()
    child.lua([[
        _G.dir = vim.fn.tempname()
        vim.fn.mkdir(_G.dir, "p")
        vim.fn.system({ "git", "-C", _G.dir, "init", "-q" })
        vim.fn.system({ "git", "-C", _G.dir, "symbolic-ref", "HEAD", "refs/heads/feature/x" })
    ]])
    eq(
        child.lua_get("{ require('github-actions.api').get_current_branch(_G.dir) }"),
        { "feature/x" }
    )
end

T["get_current_branch()"]["fails outside a repository"] = function()
    child.lua([[
        _G.dir = vim.fn.tempname()
        vim.fn.mkdir(_G.dir, "p")
        vim.env.GIT_CEILING_DIRECTORIES = vim.fn.fnamemodify(_G.dir, ":h")
    ]])
    child.lua([[_G.branch, _G.err = require('github-actions.api').get_current_branch(_G.dir)]])
    eq(child.lua_get("_G.branch == nil"), true)
    eq(child.lua_get("_G.err"), "Not in a git repository")
end

return T
