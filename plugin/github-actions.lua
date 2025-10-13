-- You can use this loaded variable to enable conditional parts of your plugin.
if _G.GithubActionsLoaded then
    return
end

_G.GithubActionsLoaded = true

vim.api.nvim_create_user_command("GithubActions", function()
    require("github-actions").toggle()
end, {})

vim.api.nvim_create_user_command("GithubActionsStatus", function()
    require("github-actions").show_ci_status()
end, { desc = "Show GitHub Actions CI/CD status" })
