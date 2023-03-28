local height = 15
local width = 100

local search_string = "";
local replace_string = "";

local selected_options = {}
local option_per_line = {}
local collapsed_files = {}

local file_list_buf = nil
local file_list_win = nil

local files = {}

local keybinds = {
    toggle_mark = "x",
    toggleCollapse = "c",
    mark_all_in_file = "a",
}

function replace_in_project()
    get_user_inputs()
    local searched_files = vim.fn.system("find . -type f -exec grep -n -H -e '" .. search_string .. "' {} +")
    replace_in_project_generic(searched_files)
end

function replace_in_git()
    get_user_inputs()
    local searched_files = vim.fn.system("git ls-files | xargs grep -n -H -e '" .. search_string .. "'")
    replace_in_project_generic(searched_files)
end

function get_user_inputs()
    search_string = vim.fn.input("Search: ")

    if search_string == "" then
        return
    end

    replace_string = vim.fn.input("Replace: ")

    if replace_string == "" then
        return
    end
end

function replace_in_project_generic(files_searched)
    for line in string.gmatch(files_searched, "[^\r\n]+") do
        local file, line_number, match_text = string.match(line, "(.+):(%d+):(.+)")
        if file then
            match_text = match_text:gsub("^%s+", "")
            match_text = trim_to_word(match_text, search_string, width - 10)
            table.insert(files, file .. ":" .. line_number .. ":" .. match_text)
        end
    end

    build_window()
    redraw_window()

    if #files == 0 then
        vim.api.nvim_buf_set_lines(file_list_buf, 0, -1, false, { "No matches found" })
    else
        vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["toggle_mark"], ":lua toggle_mark()<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["toggleCollapse"], ":lua collapse_file()<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["mark_all_in_file"], ":lua mark_all_in_file()<CR>", { noremap = true, silent = true })
    end

    -- Close the window when the user presses <Esc> or <C-c>
    vim.api.nvim_buf_set_keymap(file_list_buf, "n", "<Esc>", ":lua close_window()<CR>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(file_list_buf, "n", "<C-c>", ":lua close_window()<CR>", { noremap = true, silent = true })

    -- Submit the window when the user presses <CR>
    vim.api.nvim_buf_set_keymap(file_list_buf, "n", "<CR>", ":lua submit_window()<CR>", { noremap = true, silent = true })

    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function submit_window()
    if #files == 0 then
        close_window()
    else
        submit_changes()
    end
end

function build_window()
    local file_list_opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        focusable = false,
        border = "rounded",
    }

    file_list_buf = vim.api.nvim_create_buf(false, true)
    file_list_win = vim.api.nvim_open_win(file_list_buf, true, file_list_opts)
end

function redraw_window()
    local cursor_pos = vim.api.nvim_win_get_cursor(file_list_win)

    local old_selected_options = {}
    for k, _ in pairs(selected_options) do
        old_selected_options[k] = option_per_line[k + 1]
    end

    -- Clear the buffers
    vim.api.nvim_buf_set_lines(file_list_buf, 0, -1, false, {})
    selected_options = {}
    option_per_line = {}

    local drew_first_line = false
    local list_entries = {}
    for _, entry in ipairs(files) do
        local file, line_number, match_text = string.match(entry, "(.+):(%d+):(.+)")
        if file and line_number and match_text then
            if not list_entries[file] then
                list_entries[file] = {}
            end

            list_entries[file][line_number .. ": " .. match_text] = ""
        end
    end

    local current_line = 1
    for file, lines in pairs(list_entries) do
        local line_to_draw = (drew_first_line and -1 or 0)
        vim.api.nvim_buf_set_lines(file_list_buf, line_to_draw, -1, false, { file })
        current_line = current_line + 1
        drew_first_line = true

        if collapsed_files[file] then
            goto continue
        end

        local sorted_entries = {}
        for match_entry, _ in pairs(lines) do
            table.insert(sorted_entries, match_entry)
        end

        table.sort(sorted_entries, function(a, b)
            local a_line_number = tonumber(string.match(a, "(%d+):"))
            local b_line_number = tonumber(string.match(b, "(%d+):"))
            return a_line_number < b_line_number
        end)

        for i, match_entry in ipairs(sorted_entries) do
            local line = "  " .. match_entry
            local line_number = tonumber(string.match(match_entry, "(%d+):"))

            local was_selected = false
            for _, v in pairs(old_selected_options) do
                if v.file == file and v.line_number == line_number then
                    was_selected = true
                    selected_options[current_line] = true
                    break
                end
            end

            if was_selected then
                vim.api.nvim_buf_set_lines(file_list_buf, -1, -1, false, { "*" .. string.sub(line, 2) })
            else
                vim.api.nvim_buf_set_lines(file_list_buf, -1, -1, false, { line })
            end

            -- local matchStart, matchEnd = string.find(line, search_string)
            -- vim.api.nvim_buf_add_highlight(file_list_buf, -2, "Search", i + 1, matchStart - 1, matchEnd)
            current_line = current_line + 1
            option_per_line[current_line] = { file = file, line_number = line_number }
        end
        ::continue::
    end

    vim.api.nvim_win_set_cursor(file_list_win, cursor_pos)
end

function close_window()
    vim.api.nvim_win_close(file_list_win, true)
end

function collapse_file()
    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", true)

    local line = vim.fn.line('.')
    local line_text = vim.fn.getline(line)

    local is_line_number = string.sub(line_text, 1, 1) == "*" or string.sub(line_text, 1, 1) == " "
    if not is_line_number then
        local file = line_text
        if collapsed_files[file] then
            collapsed_files[file] = nil
        else
            collapsed_files[file] = true
        end

        redraw_window()
    end

    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function mark_all_in_file()
    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", true)

    local line = vim.fn.line('.')
    local line_text = vim.fn.getline(line)

    local is_line_number = string.sub(line_text, 1, 1) == "*" or string.sub(line_text, 1, 1) == " "
    if not is_line_number then
        local file = line_text
        local start_line = line + 1
        local end_line = start_line
        while vim.fn.getline(end_line) and string.sub(vim.fn.getline(end_line), 1, 1) == " " do
            end_line = end_line + 1
        end

        for i = start_line, end_line - 1 do
            if string.sub(line_text, 1, 1) == " " then
                selected_options[i] = true
                vim.fn.setline(i, "*" .. string.sub(line_text, 2))
            end
        end
    end

    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function toggle_mark()
    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", true)

    local mark = "*"
    local line = vim.fn.line('.')
    local line_text = vim.fn.getline(line)

    local is_line_number = string.sub(line_text, 1, 1) == mark or string.sub(line_text, 1, 1) == " "
    if is_line_number then
        -- If the line is a line number, toggle the mark on the line number
        if string.sub(line_text, 1, 1) == mark then
            selected_options[line] = nil
            vim.fn.setline(line, " " .. string.sub(line_text, 2))
        else
            selected_options[line] = true
            vim.fn.setline(line, mark .. string.sub(line_text, 2))
        end
    else
        -- If the line is a file name, toggle the mark on all line numbers
        local start_line = line + 1
        local end_line = start_line
        while end_line <= #vim.api.nvim_buf_get_lines(file_list_buf, 0, -1, false) do
            if not string.match(line_text, "%d+:") then
                break
            end
            end_line = end_line + 1
        end

        for i = start_line, end_line - 1 do
            local is_marked = string.sub(line_text, 1, 1) == mark
            if is_marked then
                selected_options[i] = nil
                vim.fn.setline(i, " " .. string.sub(line_text, 2))
            else
                selected_options[i] = true
                vim.fn.setline(i, mark .. string.sub(line_text, 2))
            end
        end
    end

    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function submit_changes()
    close_window()
    vim.cmd("write!")

    -- Loop each selected options and get info from allOptions
    for k, v in pairs(selected_options) do
        local file = option_per_line[k + 1].file
        local line_number = option_per_line[k + 1].line_number

        -- Replace all instances of the search string with the replace string
        -- in the file at the line number
        local file_contents = vim.fn.readfile(file)
        local line = file_contents[line_number]
        local new_line = line:gsub(search_string, replace_string)
        file_contents[line_number] = new_line
        vim.fn.writefile(file_contents, file)
    end

    -- Refresh the buffers
    vim.cmd("edit!")
end

function trim_to_word(str, target, maxLen)
    -- Check if string is longer than max length
    if #str > maxLen then
        -- Check if target string is in the string
        local target_index = string.find(str, target)
        if target_index then
            -- Calculate how much to trim before and after the target string
            local target_len = #target
            local trim_len = maxLen - target_len - 1
            local start_trim = math.max(target_index - trim_len, 1)
            local end_trim = math.min(target_index + target_len + trim_len - 1, #str)

            -- Trim the string
            str = string.sub(str, start_trim, end_trim)
            -- Add ellipsis if necessary
            if start_trim > 1 then
                str = "..." .. string.sub(str, start_trim)
            end
            if end_trim < #str then
                str = string.sub(str, 1, -4) .. "..."
            end
        else
            -- Trim the string without keeping target visible
            str = string.sub(str, 1, maxLen - 3) .. "..."
        end
    end

    return str
end

function setup(config)
    -- Override default keybinds
    if config.keybinds then
        keybinds = config.keybinds
    end
end

return {
    setup = setup,
    replace_in_project = replace_in_project,
    replace_in_git = replace_in_git,
}
