if vim.g.loaded_github_actions then
    return
end

vim.g.loaded_github_actions = true

vim.api.nvim_create_user_command("GithubActionsStatus", function()
    require("github-actions").show_ci_status()
end, { desc = "Show GitHub Actions CI/CD status" })
