local api = vim.api
local utils = require "tidy.utils"
local M = {}

--- Show only a sign for the highest severity diagnostic on a given line.
--- The code below follows the help message for 'diagnostic-handlers-example'.
function M.show_signs(_, bufnr, _, opts)
  --- Get all diagnostics from the whole buffer rather
  --- than just the diagnostics passed to the handler
  local diagnostics = vim.diagnostic.get(bufnr)
  --- Find the "worst" diagnostic per line
  --- (NOTE: the less - the worse)
  local max_severity_per_line = {}
  for _, d in pairs(diagnostics) do
    local m = max_severity_per_line[d.lnum]
    if not m or d.severity < m.severity then
      max_severity_per_line[d.lnum] = d
    end
  end

  local filtered_diagnostics = vim.tbl_values(max_severity_per_line)
  if
    --- It may happen that `max_severity_per_line` table is irrelevant at the
    --- moment of calling the handler. Since a user may have modified the
    --- buffer in the meantime, and in case of deleting the buffer lines, it
    --- can end up with an error "line is out of range". Checking `changedtick`
    --- doesn't help from my experience. And calling recursively the handler
    --- after pcall failed leads to stack overflow. But we don't need to retry
    --- the handler in case of an error. It will be called again anyway.
    pcall(M.orig_signs_handler.show, M.ns, bufnr, filtered_diagnostics, opts)
  then
    return
  end
end

local function marker_position(rightmost, line_length)
  if not M.cfg.virtual_text.aligned then
    local indent = M.cfg.virtual_text.marker_indent or vim.opt.tabstop:get()
    return line_length + indent
  end

  local vt_pos = rightmost
  local gap = rightmost - line_length

  if gap < 0 then
    vt_pos = vt_pos - gap
  end

  local indent = M.cfg.virtual_text.marker_indent or 1
  return vt_pos + indent
end

function M.show_virtual_text(_, bufnr)
  if
    not vim.opt.modifiable:get()
    or api.nvim_win_get_config(0).relative ~= ""
  then
    return
  end

  local imd = M.cfg.virtual_text.intermarker_distance or vim.opt.tabstop:get()
  local vt_hl = M.cfg.virtual_text.highlighting

  local cc = tonumber(vim.opt.colorcolumn:get()[1]) or 0
  local tw = vim.opt.textwidth:get()
  local rightmost = math.max(cc, tw)

  local diagnostics = vim.diagnostic.get(bufnr)
  local line_diagnostics = {}
  local diag_line_id = {}

  for _, d in pairs(diagnostics) do
    local cur_line_len = #vim.fn.getline(d.lnum + 1)
    local vt_pos = marker_position(rightmost, cur_line_len)

    local key = d.col .. d.message .. d.end_col
    line_diagnostics[d.lnum] = line_diagnostics[d.lnum] or {}
    line_diagnostics[d.lnum][key] = {
      M.cfg.virtual_text.marker,
      vt_hl[utils.severity_levels[d.severity]],
    }
    if imd > 0 then -- Not necessary to check, but might bet faster
      line_diagnostics[d.lnum][key .. "0"] = { string.rep(" ", imd) }
    end
    if not diag_line_id[d.lnum] then
      diag_line_id[d.lnum] = vt_pos
    end
  end

  for key, _ in pairs(line_diagnostics) do
    if not diag_line_id[key] then
      line_diagnostics[key] = nil
    end
  end

  for dlnum, vt_pos in pairs(diag_line_id) do
    if dlnum <= api.nvim_buf_line_count(bufnr) then
      api.nvim_buf_set_extmark(bufnr, M.ns, dlnum, 0, {
        id = dlnum + 1, -- dlnum is 0-indexed, whereas id must be > 0
        virt_text = vim.tbl_values(line_diagnostics[dlnum]),
        virt_text_win_col = vt_pos,
      })
    end
  end
end

function M.hide_virtual_text(_, bufnr)
  if bufnr ~= api.nvim_get_current_buf() then
    return
  end

  for lnum = 1, api.nvim_buf_line_count(bufnr) do
    api.nvim_buf_del_extmark(bufnr, M.ns, lnum)
  end
end

function M.toggle_plugin_diagnostic()
  if M.cfg.virtual_text.enabled then
    vim.diagnostic.enable(false, { ns_id = M.ns })
    M.cfg.virtual_text.enabled = false
    vim.diagnostic.handlers.virtual_text = {
      show = nil,
      hide = nil,
    }
  else
    vim.diagnostic.enable(true, { ns_id = M.ns })
    M.cfg.virtual_text.enabled = true
    M.show_virtual_text(nil, 0)
    vim.diagnostic.handlers.virtual_text = {
      show = M.show_virtual_text,
      hide = M.hide_virtual_text,
    }
  end
end

return M
