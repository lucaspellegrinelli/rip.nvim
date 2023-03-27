local files = vim.fn.systemlist("git ls-files")

-- Create the window
local height = 15
local width = 60
local fileListOpts = {
  style = "minimal",
  relative = "editor",
  width = width,
  height = height,
  row = math.floor((vim.o.lines - height) / 2),
  col = math.floor((vim.o.columns - width) / 2),
  bufpos = {0, 0},
  focusable = false,
  border = "rounded",
}

local fileListBuf = vim.api.nvim_create_buf(false, true)
local fileListWin = vim.api.nvim_open_win(fileListBuf, true, fileListOpts)
vim.api.nvim_buf_set_lines(fileListBuf, 0, -1, false, files)
vim.api.nvim_buf_set_option(fileListBuf, "modifiable", false)

-- Define ToggleMark function to toggle marking the selected file name with an asterisk
function ToggleMark()
    local mark = "*"
    vim.api.nvim_buf_set_option(fileListBuf, "modifiable", true)
    local line = vim.fn.line('.')
    local line_text = vim.fn.getline(line)
    if string.sub(line_text, 1, 1) == mark then
        vim.fn.setline(line, string.sub(line_text, 2))
    else
        vim.fn.setline(line, mark .. line_text)
    end
    vim.api.nvim_buf_set_option(fileListBuf, "modifiable", false)
end

-- Override enter key to mark selected file name with an asterisk
vim.api.nvim_buf_set_keymap(fileListBuf, "n", "<CR>", ":lua ToggleMark()<CR>", {noremap = true, silent = true})

