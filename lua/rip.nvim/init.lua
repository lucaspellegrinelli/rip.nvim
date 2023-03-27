local searchString = vim.fn.input("Search: ")

local output = vim.fn.system("git ls-files | xargs grep -n -H -e '" .. searchString .. "'")
local files = {}
for line in string.gmatch(output, "[^\r\n]+") do
  local file, line_number, match_text = string.match(line, "(.+):(%d+):(.+)")
  if file then
    table.insert(files, file .. ":" .. line_number .. ":" .. match_text)
  end
end

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

-- Build the tree
local tree = {}
for _, entry in ipairs(files) do
  local file, line_number, match_text = string.match(entry, "(.+):(%d+):(.+)")
  if file and line_number and match_text then
    if not tree[file] then
      tree[file] = {}
    end
    tree[file][line_number .. ":" .. match_text] = ""
  end
end

-- Add the entries to the buffer recursively
local function add_entries(node, indent)
  for key, value in pairs(node) do
    local line = string.rep(" ", indent) .. key
    vim.api.nvim_buf_set_lines(fileListBuf, -1, -1, false, {line})
    if type(value) == "table" then
      add_entries(value, indent + 2)
    end
  end
end

add_entries(tree, 0)

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

