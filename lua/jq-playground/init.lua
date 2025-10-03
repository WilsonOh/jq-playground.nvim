local M = {}

function M.setup(opts)
  local confmod = require("jq-playground.config")

  confmod.config = vim.tbl_deep_extend("force", confmod.default_config, opts or {})

  vim.api.nvim_create_user_command("JqPlaygroundToggle", function()
    local curbuf = vim.api.nvim_get_current_buf()
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = curbuf })
    if filetype ~= "json" then
      vim.notify_once("jq playground not availble for non-json files", vim.log.levels.ERROR)
      return
    end
    require("jq-playground.playground").toggle_playground()
  end, {
    desc = "Toggle jq playground",
  })
end

return M
