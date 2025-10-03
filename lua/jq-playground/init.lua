local M = {}

function M.setup(opts)
  local confmod = require("jq-playground.config")

  confmod.config = vim.tbl_deep_extend("force", confmod.default_config, opts or {})

  vim.api.nvim_create_user_command("JqPlaygroundToggle", function()
    require("jq-playground.playground").toggle_playground()
  end, {
    desc = "Toggle jq playground",
  })
end

return M
