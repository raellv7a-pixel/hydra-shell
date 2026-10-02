-- Hydra Shell: require('hydra-colors') from init.lua.
-- Own Base16-shaped ANSI mapping using only Neovim's public APIs.
local c = {
  '{{colors.terminal_normal_black.default.hex}}',
  '{{colors.terminal_normal_red.default.hex}}',
  '{{colors.terminal_normal_green.default.hex}}',
  '{{colors.terminal_normal_yellow.default.hex}}',
  '{{colors.terminal_normal_blue.default.hex}}',
  '{{colors.terminal_normal_magenta.default.hex}}',
  '{{colors.terminal_normal_cyan.default.hex}}',
  '{{colors.terminal_normal_white.default.hex}}',
  '{{colors.terminal_bright_black.default.hex}}',
  '{{colors.terminal_bright_red.default.hex}}',
  '{{colors.terminal_bright_green.default.hex}}',
  '{{colors.terminal_bright_yellow.default.hex}}',
  '{{colors.terminal_bright_blue.default.hex}}',
  '{{colors.terminal_bright_magenta.default.hex}}',
  '{{colors.terminal_bright_cyan.default.hex}}',
  '{{colors.terminal_bright_white.default.hex}}',
}
local fg = '{{colors.terminal_foreground.default.hex}}'
local bg = '{{colors.terminal_background.default.hex}}'
vim.o.termguicolors = true
vim.o.background = '{{mode}}'
vim.g.colors_name = 'hydra'
for index, color in ipairs(c) do vim.g['terminal_color_' .. (index - 1)] = color end
local groups = {
  Normal = { fg = fg, bg = bg },
  NormalFloat = { fg = fg, bg = '{{colors.surface_container.default.hex}}' },
  FloatBorder = { fg = '{{colors.outline.default.hex}}' },
  Cursor = { fg = bg, bg = '{{colors.terminal_cursor.default.hex}}' },
  Visual = { fg = '{{colors.terminal_selection_foreground.default.hex}}', bg = '{{colors.terminal_selection_background.default.hex}}' },
  CursorLine = { bg = '{{colors.surface_container_low.default.hex}}' },
  ColorColumn = { bg = '{{colors.surface_container.default.hex}}' },
  LineNr = { fg = c[9] }, CursorLineNr = { fg = c[4], bold = true },
  StatusLine = { fg = fg, bg = '{{colors.surface_container.default.hex}}' },
  StatusLineNC = { fg = c[9], bg = bg },
  Pmenu = { fg = fg, bg = '{{colors.surface_container.default.hex}}' },
  PmenuSel = { fg = '{{colors.on_primary.default.hex}}', bg = '{{colors.primary.default.hex}}' },
  Comment = { fg = c[9], italic = true },
  String = { fg = c[3] }, Character = { link = 'String' },
  Number = { fg = c[6] }, Boolean = { link = 'Number' }, Float = { link = 'Number' },
  Keyword = { fg = c[5] }, Statement = { link = 'Keyword' },
  Function = { fg = c[7] }, Identifier = { fg = fg },
  Type = { fg = c[4] }, Special = { fg = c[2] },
  Error = { fg = '{{colors.on_error_container.default.hex}}', bg = '{{colors.error_container.default.hex}}' },
  Search = { fg = bg, bg = c[4] }, IncSearch = { fg = bg, bg = c[6] },
  DiagnosticError = { fg = c[2] }, DiagnosticWarn = { fg = c[4] },
  DiagnosticInfo = { fg = c[5] }, DiagnosticHint = { fg = c[7] },
  DiffAdd = { fg = c[3], bg = '{{colors.surface_container_low.default.hex}}' },
  DiffDelete = { fg = c[2], bg = '{{colors.surface_container_low.default.hex}}' },
  DiffChange = { fg = c[4], bg = '{{colors.surface_container_low.default.hex}}' },
  TelescopeNormal = { link = 'NormalFloat' }, TelescopeBorder = { link = 'FloatBorder' },
  TelescopeSelection = { link = 'Visual' }, MiniPickNormal = { link = 'NormalFloat' },
  MiniPickBorder = { link = 'FloatBorder' }, MiniPickMatchCurrent = { link = 'Visual' },
  ['@string'] = { link = 'String' }, ['@number'] = { link = 'Number' },
  ['@keyword'] = { link = 'Keyword' }, ['@function'] = { link = 'Function' },
  ['@type'] = { link = 'Type' }, ['@comment'] = { link = 'Comment' },
}
for group, attributes in pairs(groups) do vim.api.nvim_set_hl(0, group, attributes) end

-- Opt-in reload watches only this file's directory; never signal other Neovims.
local path = debug.getinfo(1, 'S').source:sub(2)
local directory = vim.fn.fnamemodify(path, ':h')
local filename = vim.fn.fnamemodify(path, ':t')
local uv = vim.uv or vim.loop
local state = rawget(_G, 'hydra_colors_state') or {}
_G.hydra_colors_state = state
local function close_watcher()
  if state.watcher then
    state.watcher:stop()
    state.watcher:close()
    state.watcher = nil
  end
end
close_watcher()
state.watcher = uv.new_fs_event()
if state.watcher then
  local started = state.watcher:start(directory, {}, function(err, changed)
    if err or (changed and changed ~= filename) or state.pending then return end
    state.pending = true
    vim.defer_fn(function()
      state.pending = false
      local ok, result = pcall(dofile, path)
      if not ok then vim.notify('Hydra theme reload: ' .. tostring(result), vim.log.levels.WARN) end
    end, 80)
  end)
  if not started then close_watcher() end
end
local group = vim.api.nvim_create_augroup('HydraColors', { clear = true })
vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = close_watcher })
return c
