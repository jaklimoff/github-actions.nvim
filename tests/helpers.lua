-- Adapted from https://github.com/echasnovski/mini.nvim
local Helpers = {}

Helpers.expect = vim.deepcopy(MiniTest.expect)

local function error_message(str, pattern)
    return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str)
end

Helpers.expect.global = MiniTest.new_expectation(
    "variable in child process matches",
    function(child, field, value)
        return Helpers.expect.equality(child.lua_get(field), value)
    end,
    error_message
)

Helpers.expect.global_type = MiniTest.new_expectation(
    "variable type in child process matches",
    function(child, field, value)
        return Helpers.expect.global(child, "type(" .. field .. ")", value)
    end,
    error_message
)

Helpers.expect.config = MiniTest.new_expectation(
    "config option matches",
    function(child, field, value)
        return Helpers.expect.global(
            child,
            "require('github-actions.config').options." .. field,
            value
        )
    end,
    error_message
)

Helpers.new_child_neovim = function()
    return MiniTest.new_child_neovim()
end

return Helpers
