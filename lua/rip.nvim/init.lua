function trimToWord(str, target, maxLen)
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

local searchString = "";
local replaceString = "";

local selectedOptions = {}
local optionPerLine = {}

local fileListBuf = nil
local fileListWin = nil

function replaceInProject()
    local searchString, replaceString = getUserInputs()
    local searchedFiles = vim.fn.system("find . -type f -exec grep -n -H -e '" .. searchString .. "' {} +")
    replaceInProjectGeneric(searchString, replaceString, searchedFiles)
end

function replaceInGit()
    local searchString, replaceString = getUserInputs()
    local searchedFiles = vim.fn.system("git ls-files | xargs grep -n -H -e '" .. searchString .. "'")
    replaceInProjectGeneric(searchString, replaceString, searchedFiles)
end

function getUserInputs()
    searchString = vim.fn.input("Search: ")

    if searchString == "" then
        return
    end

    replaceString = vim.fn.input("Replace: ")

    if replaceString == "" then
        return
    end

    return searchString, replaceString
end

function replaceInProjectGeneric(searchString, replaceString, filesSearched)
    selectedOptions = {}
    optionPerLine = {}

    local files = {}
    for line in string.gmatch(filesSearched, "[^\r\n]+") do
        local file, line_number, match_text = string.match(line, "(.+):(%d+):(.+)")
        if file then
            match_text = match_text:gsub("^%s+", "")
            match_text = trimToWord(match_text, searchString, width - 10)
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

    fileListBuf = vim.api.nvim_create_buf(false, true)
    fileListWin = vim.api.nvim_open_win(fileListBuf, true, fileListOpts)

    local listEntries = {}
    for _, entry in ipairs(files) do
        local file, line_number, match_text = string.match(entry, "(.+):(%d+):(.+)")
        if file and line_number and match_text then
            if not listEntries[file] then
                listEntries[file] = {}
            end

            listEntries[file][line_number .. ": " .. match_text] = ""
        end
    end

    local currentLine = 1
    for file, lines in pairs(listEntries) do
        vim.api.nvim_buf_set_lines(fileListBuf, -1, -1, false, { file })
        currentLine = currentLine + 1

        local sortedEntries = {}
        for matchEntry, _ in pairs(lines) do
            table.insert(sortedEntries, matchEntry)
        end

        table.sort(sortedEntries, function(a, b)
            local a_line_number = tonumber(string.match(a, "(%d+):"))
            local b_line_number = tonumber(string.match(b, "(%d+):"))
            return a_line_number < b_line_number
        end)

        for i, matchEntry in ipairs(sortedEntries) do
            local line = "  " .. matchEntry
            vim.api.nvim_buf_set_lines(fileListBuf, -1, -1, false, { line })
            local matchStart, matchEnd = string.find(line, searchString)
            vim.api.nvim_buf_add_highlight(fileListBuf, -1, "Search", i + 1, matchStart - 1, matchEnd)
            currentLine = currentLine + 1

            optionPerLine[currentLine] = { file = file, line_number = tonumber(string.match(matchEntry, "(%d+):")) }
        end
    end
    vim.api.nvim_buf_set_option(fileListBuf, "modifiable", false)
    vim.api.nvim_buf_set_keymap(fileListBuf, "n", "<CR>", ":lua toggleMark()<CR>", { noremap = true, silent = true })
end

function toggleMark()
    vim.api.nvim_buf_set_option(fileListBuf, "modifiable", true)

    local mark = "*"
    local line = vim.fn.line('.')
    local line_text = vim.fn.getline(line)

    local isLineNumber = string.sub(line_text, 1, 1) == mark or string.sub(line_text, 1, 1) == " "
    if isLineNumber then
        -- If the line is a line number, toggle the mark on the line number
        if string.sub(line_text, 1, 1) == mark then
            selectedOptions[line] = nil
            vim.fn.setline(line, " " .. string.sub(line_text, 2))
        else
            selectedOptions[line] = true
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
                selectedOptions[i] = nil
                vim.fn.setline(i, " " .. string.sub(line_text, 2))
            else
                selectedOptions[i] = true
                vim.fn.setline(i, mark .. string.sub(line_text, 2))
            end
        end
    end

    vim.api.nvim_buf_set_option(fileListBuf, "modifiable", false)
end

function submitChanges()
    -- print(vim.inspect(selectedOptions))
    -- print(vim.inspect(optionPerLine))

    -- Close the window
    vim.api.nvim_win_close(fileListWin, true)

    vim.cmd("write!")

    -- Loop each selected options and get info from allOptions
    for k, v in pairs(selectedOptions) do
        local file = optionPerLine[k].file
        local line_number = optionPerLine[k].line_number

        -- Replace all instances of the search string with the replace string
        -- in the file at the line number
        local fileContents = vim.fn.readfile(file)
        local line = fileContents[line_number]
        local newLine = line:gsub(searchString, replaceString)
        fileContents[line_number] = newLine
        vim.fn.writefile(fileContents, file)
    end

    -- Refresh the buffers
    vim.cmd("edit!")
end

-- rummy
