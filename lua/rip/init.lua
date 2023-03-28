vim.cmd('highlight HighlightedSearchColor guifg=#ffff00')

local height = 15
local width = 100

local search_string = "";
local replace_string = "";

local selected_options = {}
local selected_options_count = 0

local option_per_line = {}
local collapsed_files = {}
local marked_files = {}

local file_list_buf = nil
local file_list_win = nil

local files = {}

local keybinds = {
    toggle_mark = "x",
    toggle_collapse = "c",
    toggle_mark_all_in_file = "a",
    confirm_replace = "<CR>",
    cancel_replace = "<Esc>",
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
    reset_search()

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
    set_keybinds()

    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function reset_search()
    files = {}
    selected_options = {}
    selected_options_count = 0
    option_per_line = {}
    collapsed_files = {}
end

function set_keybinds()
    if #files == 0 then
        vim.api.nvim_buf_set_lines(file_list_buf, 0, -1, false, { "No matches found for '" .. search_string .. "'" })
    else
        vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["toggle_mark"], ":lua toggle_mark()<CR>",
            { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["toggle_collapse"], ":lua collapse_file()<CR>",
            { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["toggle_mark_all_in_file"],
            ":lua toggle_mark_all_in_file()<CR>",
            { noremap = true, silent = true })
    end

    vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["confirm_replace"], ":lua submit_window()<CR>",
        { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["cancel_replace"], ":lua close_window()<CR>",
        { noremap = true, silent = true })
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

    -- Clear the buffers
    vim.api.nvim_buf_set_lines(file_list_buf, 0, -1, false, {})
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

        for _, match_entry in ipairs(sorted_entries) do
            local line_number = tonumber(string.match(match_entry, "(%d+):"))
            local is_selected = get_selected_state(file, line_number)

            local line = "  " .. match_entry
            if is_selected then
                line = "*" .. string.sub(line, 2)
            end

            set_highlighted_text(file_list_buf, current_line, line, search_string)

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

    local file_name = nil
    if is_line_number(line_text) then
        local option = option_per_line[line + 1]
        if option then
            file_name = option.file
        end
    else
        file_name = line_text
    end

    if file_name then
        if collapsed_files[file_name] then
            collapsed_files[file_name] = nil
        else
            collapsed_files[file_name] = true
        end
    end

    redraw_window()

    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function toggle_mark_all_in_file()
    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", true)

    local line = vim.fn.line('.')
    local line_text = vim.fn.getline(line)

    local was_marked = marked_files[line_text] ~= nil
    if was_marked then
        marked_files[line_text] = nil
    else
        marked_files[line_text] = true
    end

    if not is_line_number(line_text) then
        local start_line = line + 1
        local end_line = start_line

        while vim.fn.getline(end_line) do
            local current_end_line = vim.fn.getline(end_line)
            if not is_line_number(current_end_line) then
                break
            end

            end_line = end_line + 1
        end

        for i = start_line, end_line - 1 do
            local option = option_per_line[i + 1]
            set_selected_state(option.file, option.line_number, not was_marked)

            local tmp_line_text = vim.fn.getline(i)
            local new_line_text = get_marked_line(tmp_line_text, not was_marked)
            set_highlighted_text(file_list_buf, i, new_line_text, search_string)
        end
    end

    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function set_highlighted_text(buffer, line, text, highlighted_text)
    vim.api.nvim_buf_set_lines(buffer, line - 1, line, false, { text })
    local match_start, match_end = string.find(text, highlighted_text)
    if match_start then
        vim.api.nvim_buf_add_highlight(buffer, 0, 'HighlightedSearchColor', line - 1, match_start - 1, match_end)
    end
end

function toggle_mark()
    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", true)

    local line = vim.fn.line('.')
    local line_text = vim.fn.getline(line)

    if is_line_number(line_text) then
        local was_marked = is_line_marked(line_text)
        local updated_line = get_marked_line(line_text, not was_marked)
        local option = option_per_line[line + 1]
        set_selected_state(option.file, option.line_number, not was_marked)
        set_highlighted_text(file_list_buf, line, updated_line, search_string)
    else
        toggle_mark_all_in_file()
    end

    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function submit_changes()
    close_window()
    vim.cmd("write!")

    for k, _ in pairs(selected_options) do
        local file = option_per_line[k + 1].file
        local line_number = option_per_line[k + 1].line_number

        local file_contents = vim.fn.readfile(file)
        local line = file_contents[line_number]
        local new_line = line:gsub(search_string, replace_string)
        file_contents[line_number] = new_line
        vim.fn.writefile(file_contents, file)
    end

    vim.cmd("edit!")
end

function trim_to_word(str, target, max_len)
    if #str > max_len then
        local target_index = string.find(str, target)
        if target_index then
            local target_len = #target
            local trim_len = max_len - target_len - 1
            local start_trim = math.max(target_index - trim_len, 1)
            local end_trim = math.min(target_index + target_len + trim_len - 1, #str)

            str = string.sub(str, start_trim, end_trim)

            if start_trim > 1 then
                str = "..." .. string.sub(str, start_trim)
            end

            if end_trim < #str then
                str = string.sub(str, 1, -4) .. "..."
            end
        else
            str = string.sub(str, 1, max_len - 3) .. "..."
        end
    end

    return str
end

function is_line_number(line)
    return string.sub(line, 1, 1) == "*" or string.sub(line, 1, 1) == " "
end

function is_line_marked(line)
    return string.sub(line, 1, 1) == "*"
end

function get_marked_line(line, marked)
    if marked then
        return "*" .. string.sub(line, 2)
    else
        return " " .. string.sub(line, 2)
    end
end

function get_selected_state(file, line_number)
    for _, v in pairs(selected_options) do
        if v.file == file and v.line_number == line_number then
            return true
        end
    end

    return false
end

function set_selected_state(file, line_number, selected)
    local already_selected_idx = nil
    for k, v in pairs(selected_options) do
        if v.file == file and v.line_number == line_number then
            already_selected_idx = k
            break
        end
    end

    if already_selected_idx then
        if not selected then
            selected_options[already_selected_idx] = nil
        end
    else
        if selected then
            selected_options_count = selected_options_count + 1
            selected_options[selected_options_count] = { file = file, line_number = line_number }
        end
    end
end

function setup(config)
    if config.keybinds then
        keybinds = config.keybinds
    end
end

return {
    setup = setup,
    replace_in_project = replace_in_project,
    replace_in_git = replace_in_git,
}
