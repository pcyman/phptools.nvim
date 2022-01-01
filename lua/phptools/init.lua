local M = {}

function M.setup()
  vim.cmd("command! PhpToolsGetSet :lua require'phptools.getset'.generate_getset()<CR>")
  vim.cmd("command! -range PhpToolsGetSetVisual :lua require'phptools.getset'.generate_getset('v')<CR>")
  vim.cmd("command! PhpToolsGenTest :lua require'phptools.unitgen'.generate_test()<CR>")
end

M.generate_getset = require('phptools.getset').generate_getset
M.generate_test = require('phptools.unitgen').generate_test

return M
