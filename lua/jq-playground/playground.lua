local Job = require("plenary.job")

local M = {
  cfg = nil,
  open = false,
  loaded = false,
  query_bufnr = nil,
  query_winnr = nil,
  output_bufnr = nil,
  output_winnr = nil,
}

local function show_error(msg)
  vim.notify("jq-playground: " .. msg, vim.log.levels.ERROR, {})
end

local function run_query(cmd, input_bufnr, query_buf, output_buf)
  local filter_lines = vim.api.nvim_buf_get_lines(query_buf, 0, -1, false)
  local filter = table.concat(filter_lines, "\n")
  local input_lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)

  --- @type string[]
  local res = {}
  --- @type string[]
  local error_lines = {}

  Job:new({
    command = cmd,
    on_stdout = function(_, data)
      table.insert(res, data)
    end,
    on_stderr = function(_, data)
      table.insert(error_lines, data)
    end,
    args = { filter },
    writer = input_lines,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          local error_msg = table.concat(error_lines, "\n")
          show_error(error_msg)
          return
        end

        vim.api.nvim_set_option_value("modifiable", true, { buf = output_buf })
        vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, res)
        vim.api.nvim_set_option_value("modifiable", false, { buf = output_buf })
      end)
    end,
  }):start()
end

local function resolve_winsize(num, max)
  if num == nil or (1 <= num and num <= max) then
    return num
  elseif 0 < num and num < 1 then
    return math.floor(num * max)
  else
    show_error(string.format("incorrect winsize, received %s of max %s", num, max))
  end
end

function M.open_window(opts, bufnr)
  local height = resolve_winsize(opts.height, vim.api.nvim_win_get_height(0))
  local width = resolve_winsize(opts.width, vim.api.nvim_win_get_width(0))

  local winid = vim.api.nvim_open_win(bufnr, true, {
    split = opts.split_direction,
    width = width,
    height = height,
  })

  return winid
end

function M.init_playground()
  local cfg = require("jq-playground.config").config
  M.cfg = cfg

  local curbuf = vim.api.nvim_get_current_buf()

  M.output_bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[M.output_bufnr].filetype = "json"
  vim.api.nvim_buf_set_name(M.output_bufnr, "jq output")
  vim.api.nvim_set_option_value("modifiable", false, { buf = M.output_bufnr })

  M.query_bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[M.query_bufnr].filetype = "jq"
  vim.api.nvim_buf_set_name(M.query_bufnr, "jq query")

  vim.keymap.set({ "n" }, "<CR>", function()
    run_query(cfg.cmd, curbuf, M.query_bufnr, M.output_bufnr)
  end, {
    buffer = M.query_bufnr,
    silent = true,
    desc = "run jq query",
  })

  vim.keymap.set("n", "y", function()
    vim.cmd([[%y+]])
    vim.notify("copied jq output to clipboard", vim.log.levels.INFO)
  end, { buffer = M.output_bufnr })
end

function M.open_playground()
  M.output_winnr = M.open_window(M.cfg.output_window, M.output_bufnr)
  M.query_winnr = M.open_window(M.cfg.query_window, M.query_bufnr)
end

M.close_playground = function()
  vim.api.nvim_win_hide(M.output_winnr)
  vim.api.nvim_win_hide(M.query_winnr)
end

M.toggle_playground = function()
  if not M.loaded then
    local curbuf = vim.api.nvim_get_current_buf()
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = curbuf })
    if filetype ~= "json" then
      vim.notify_once("jq playground not availble for non-json files", vim.log.levels.ERROR)
      return
    end
    M.init_playground()
    M.loaded = true
  end

  if not M.open then
    M.open_playground()
    M.open = true
  else
    M.close_playground()
    M.open = false
  end
end

return M
