-- create a new highlight group with a red foreground color
vim.cmd('highlight RedText guifg=#ff0000')
vim.cmd('highlight GreenText guifg=#00ff00')
vim.cmd('highlight BlueText guifg=#0000ff')

-- create a new buffer for the popup window
local buf = vim.api.nvim_create_buf(false, true)

-- set the text in the buffer and apply the new highlight group
vim.api.nvim_buf_set_text(buf, 0, 0, 0, 0, {'This text is in red.'})
vim.api.nvim_buf_add_highlight(buf, -1, 'RedText', 0, 0, 5)
vim.api.nvim_buf_add_highlight(buf, -1, 'GreenText', 0, 5, 11)
vim.api.nvim_buf_add_highlight(buf, -1, 'BlueText', 0, 11, 17)

-- create a new popup window with the buffer
local width = 30
local height = 5
local row = math.floor((vim.o.lines - height) / 2)
local col = math.floor((vim.o.columns - width) / 2)
local opts = {
  relative = 'editor',
  style = 'minimal',
  width = width,
  height = height,
  row = row,
  col = col
}
local win = vim.api.nvim_open_win(buf, true, opts)

