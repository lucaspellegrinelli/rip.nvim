local utils = require("rip.utils")
local window = require("rip.window")

M = {}

local all_files_marked = false

function M.toggle_mark()
    local state = window.state
    vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)

    local line = vim.fn.line(".")
    local line_text = vim.fn.getline(line)

    if utils.is_line_number(line_text) then
        local was_marked = utils.is_line_marked(line_text)
        local updated_line = utils.get_marked_line(line_text, not was_marked)
        local option = state.item_in_line[line + 1]
        window.set_selected_state(option.file, option.line_number, not was_marked)
        window.set_highlighted_text(line, updated_line)
    else
        window.toggle_mark_all_in_file()
    end

    vim.api.nvim_buf_set_option(state.buffer, "modifiable", false)
end

function M.collapse_file()
    local state = window.state
    vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)

    local line = vim.fn.line(".")
    local line_text = vim.fn.getline(line)

    local file_name = nil
    if utils.is_line_number(line_text) then
        local option = state.item_in_line[line + 1]
        if option then
            file_name = option.file
        end
    else
        file_name = line_text
    end

    if file_name then
        if state.collapsed_files[file_name] then
            state.collapsed_files[file_name] = nil
        else
            state.collapsed_files[file_name] = true
        end
    end

    window.redraw_window()
    vim.api.nvim_buf_set_option(state.buffer, "modifiable", false)
end

function M.toggle_mark_all()
    local state = window.state
    vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)

    all_files_marked = not all_files_marked

    for i = 1, vim.fn.line("$") do
        local line_text = vim.fn.getline(i)
        if utils.is_line_number(line_text) then
            local option = state.item_in_line[i + 1]
            window.set_selected_state(option.file, option.line_number, all_files_marked)

            local new_line_text = utils.get_marked_line(line_text, all_files_marked)
            window.set_highlighted_text(i, new_line_text)
        end
    end

    vim.api.nvim_buf_set_option(state.buffer, "modifiable", false)
end

function M.submit_changes()
    local state = window.state

    if #state.selected_items > 0 then
        local current_file = vim.fn.expand("%:p")
        if current_file ~= "" then
            vim.cmd("write")
        end

        for _, v in pairs(state.selected_items) do
            local file = v.file
            local line_number = v.line_number

            local file_contents = vim.fn.readfile(file)
            local line = file_contents[line_number]
            local new_line = line:gsub(state.searched_string, state.replace_string)
            file_contents[line_number] = new_line
            vim.fn.writefile(file_contents, file)
        end

        if current_file ~= "" then
            vim.cmd("edit!")
        end
    end

    window.close_window()
end

function M.close_window()
    window.close_window()
end

return M
