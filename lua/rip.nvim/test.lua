-- Open a new window and buffer
local buf = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_open_win(buf, true, {
    relative='editor',
    width=20,
    height=1,
    row=1,
    col=1
})

-- Set the buffer contents
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"Hello, world!"})

-- Add highlighting to the text
vim.api.nvim_buf_add_highlight(buf, -1, "Search", 0, 6, 12)

-- Wait for a key press to close the window
