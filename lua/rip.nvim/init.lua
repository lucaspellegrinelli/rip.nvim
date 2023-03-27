function trimString(str, maxLen, target)
    -- Check if string is longer than max length
    if #str > maxLen then
        -- Check if target string is in the string
        local targetIndex = string.find(str, target)
        if targetIndex then
            -- Calculate how much to trim before and after the target string
            local targetLen = #target
            local trimLen = maxLen - targetLen - 1
            local startTrim = math.max(targetIndex - trimLen, 1)
            local endTrim = math.min(targetIndex + targetLen + trimLen - 1, #str)

            -- Trim the string
            str = string.sub(str, startTrim, endTrim)
            -- Add ellipsis if necessary
            if startTrim > 1 then
                str = "..." .. string.sub(str, startTrim)
            end
            if endTrim < #str then
                str = string.sub(str, 1, -4) .. "..."
            end
        else
            -- Trim the string without keeping target visible
            str = string.sub(str, 1, maxLen - 3) .. "..."
        end
    end

    return str
end

local height = 15
local width = 100

local searchString = vim.fn.input("Search: ")
local replaceString = vim.fn.input("Replace: ")

local output = vim.fn.system("git ls-files | xargs grep -n -H -e '" .. searchString .. "'")
local files = {}
for line in string.gmatch(output, "[^\r\n]+") do
    local file, line_number, match_text = string.match(line, "(.+):(%d+):(.+)")
    if file then
        match_text = match_text:gsub("^%s+", "")
        match_text = trimString(match_text, width - 10, searchString)
        table.insert(files, file .. ":" .. line_number .. ":" .. match_text)
    end
end
-- Create the window

local fileListOpts = {
    style = "minimal",
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    bufpos = { 0, 0 },
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

        tree[file][line_number .. ": " .. match_text] = ""
    end
end

-- Add the entries to the buffer recursively
local function add_entries(node, indent)
    for file, lines in pairs(node) do
        -- Add the file name entry
        local file_line = string.rep(" ", indent) .. file
        vim.api.nvim_buf_set_lines(fileListBuf, -1, -1, false, { file_line })

        -- Sort and add the line number entries
        local sorted_lines = {}
        for line_number_match_text, _ in pairs(lines) do
            table.insert(sorted_lines, line_number_match_text)
        end

        table.sort(sorted_lines, function(a, b)
            local a_line_number = tonumber(string.match(a, "(%d+):"))
            local b_line_number = tonumber(string.match(b, "(%d+):"))
            return a_line_number < b_line_number
        end)

        for i, line_number_match_text in ipairs(sorted_lines) do
            local line = string.rep(" ", indent + 2) .. line_number_match_text
            vim.api.nvim_buf_set_lines(fileListBuf, -1, -1, false, { line })
            local matchStart, matchEnd = string.find(line, searchString)
            vim.api.nvim_buf_add_highlight(fileListBuf, -1, "Search", i + 1, matchStart - 1, matchEnd)
        end
    end
end

add_entries(tree, 0)

vim.api.nvim_buf_set_option(fileListBuf, "modifiable", false)

function ToggleMark()
    vim.api.nvim_buf_set_option(fileListBuf, "modifiable", true)

    local mark = "*"
    local line = vim.fn.line('.')
    local line_text = vim.fn.getline(line)

    local isLineNumber = string.sub(line_text, 1, 1) == mark or string.sub(line_text, 1, 1) == " "
    if isLineNumber then
        -- If the line is a line number, toggle the mark on the line number
        if string.sub(line_text, 1, 1) == mark then
            vim.fn.setline(line, " " .. string.sub(line_text, 2))
        else
            vim.fn.setline(line, mark .. string.sub(line_text, 2))
        end
    else
        -- If the line is a file name, toggle the mark on all line numbers
        local start_line = line + 1
        local end_line = start_line
        while end_line <= #vim.api.nvim_buf_get_lines(fileListBuf, 0, -1, false) do
            local line_text = vim.fn.getline(end_line)
            if not string.match(line_text, "%d+:") then
                break
            end
            end_line = end_line + 1
        end

        for i = start_line, end_line - 1 do
            local line_text = vim.fn.getline(i)
            local is_marked = string.sub(line_text, 1, 1) == mark
            if is_marked then
                vim.fn.setline(i, " " .. string.sub(line_text, 2))
            else
                vim.fn.setline(i, mark .. string.sub(line_text, 2))
            end
        end
    end

    vim.api.nvim_buf_set_option(fileListBuf, "modifiable", false)
end

function submit_changes()
    local lines = vim.api.nvim_buf_get_lines(fileListBuf, 0, -1, false)
    local files = {}
    local lines_to_change = {}
    for _, line in ipairs(lines) do
        local is_marked = string.sub(line, 1, 1) == "*"
        if is_marked then
            local file, line_number, match_text = string.match(line, "%s*(.+):(%d+):(.+)")
            if file and line_number and match_text then
                if not files[file] then
                    files[file] = {}
                end
                table.insert(files[file], line_number)
            end
        end
    end
    for file, line_numbers in pairs(files) do
        local command = "sed -i "
        for _, line_number in ipairs(line_numbers) do
            command = command .. "'" .. line_number .. "s/" .. searchString .. "/" .. replaceString .. "/' "
        end
        command = command .. file
        vim.fn.system(command)
    end

    vim.api.nvim_win_close(fileListWin, true)
end

-- Override enter key to mark selected file name with an asterisk
vim.api.nvim_buf_set_keymap(fileListBuf, "n", "<leader>", ":lua ToggleMark()<CR>", { noremap = true, silent = true })
vim.api.nvim_buf_set_keymap(fileListBuf, "n", "<CR>", ":lua submit_changes()<CR>", { noremap = true, silent = true })

-- Dummy
