local lspconf = require "tidy.lspconf"
local utils = require "tidy.utils"
local api = vim.api
local M = {}

local ns = api.nvim_create_namespace "CustomDiagnosticHandlers"
local orig_signs_handler = vim.diagnostic.handlers.signs

api.nvim_create_user_command("Format", utils.lsp_format, { range = "%" })
lspconf.orig_signs_handler = orig_signs_handler
lspconf.ns = ns

local function format_diagnostic(diagnostic)
  if diagnostic.user_data ~= nil and diagnostic.user_data.lsp ~= nil then
    local code = diagnostic.user_data.lsp.code
    if code ~= nil then
      return string.format("%s: %s", code, diagnostic.message)
    end
  end
  return diagnostic.message
end

function M.setup(cfg)
  lspconf.cfg = vim.tbl_deep_extend("keep", cfg or {}, utils.default)
  utils.set_signs(lspconf.cfg.signs)

  if lspconf.cfg.signs then
    vim.diagnostic.handlers.signs = {
      show = lspconf.show_signs,
      hide = function(_, bufnr)
        orig_signs_handler.hide(ns, bufnr)
      end,
    }
  end

  if lspconf.cfg.virtual_text and lspconf.cfg.virtual_text.enabled then
    vim.diagnostic.handlers.virtual_text = {
      show = lspconf.show_virtual_text,
      hide = lspconf.hide_virtual_text,
    }
  end

  vim.diagnostic.config {
    severity_sort = not lspconf.cfg.signs,
    signs = true,
    virtual_lines = {
      current_line = true,
      format = function(diagnostic)
        if diagnostic.severity then
          local severity = vim.diagnostic.severity[diagnostic.severity]
          if vim.tbl_contains({ "ERROR", "WARN" }, severity) then
            return format_diagnostic(diagnostic)
          end
        end
      end,
    },
    virtual_text = {
      source = false,
      format = function(_)
        return ""
      end,
    },
    float = {
      source = true,
      focus = false,
      format = format_diagnostic,
    },
  }
end

return M
