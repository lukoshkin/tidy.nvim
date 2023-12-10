local M = {}
local api = vim.api
local fn = vim.fn

M.severity_levels = {
  [1] = "Error",
  [2] = "Warn",
  [3] = "Info",
  [4] = "Hint",
}

M.default = {
  signs = {
    Error = { text = "", texthl = "DiagnosticSignError" },
    Warn = { text = "", texthl = "DiagnosticSignWarn" },
    Info = { text = "", texthl = "DiagnosticSignInfo" },
    Hint = { text = "", texthl = "DiagnosticSignHint" },
  },
  virtual_text = {
    marker = "◆",
    marker_indent = 1,
    intermarker_distance = 0,
    aligned = true,
    highlighting = {
      Error = "DiagnosticVirtualTextError",
      Warn = "DiagnosticVirtualTextWarn",
      Info = "DiagnosticVirtualTextInfo",
      Hint = "DiagnosticVirtualTextHint",
    },
  }
}

function M.set_signs(signs)
  for _, name in pairs({ "Error", "Warn", "Info", "Hint" }) do
    fn.sign_define("DiagnosticSign" .. name, signs[name])
  end
end

function M.lsp_format(opts)
  if vim.lsp.buf.format then
    local args = { async = true }
    if opts.range > 0 then
      args.range = {}
      args.range["start"] = api.nvim_buf_get_mark(0, "<")
      args.range["end"] = api.nvim_buf_get_mark(0, ">")
    end

    vim.lsp.buf.format(args)
    return
  end

  --- Deprecated formatting for older Nvim versions.
  vim.lsp.buf.formatting()
end

return M
