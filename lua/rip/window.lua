local utils = require("rip.utils")
local file_ops = require("rip.file_ops")

local M = {}

local file_list_buf = nil
local file_list_win = nil

local files = {}
local selected_options = {}
local option_per_line = {}
local collapsed_files = {}
local marked_files = {}
local all_files_marked = false

local width = math.floor(vim.o.columns * 0.75)
local height = math.floor(vim.o.lines * 0.5)

function M.setup()
	vim.cmd("highlight HighlightedSearchColor guifg=#e9b565")
    return file_list_buf
end

function M.build_window()
	M.update_window_dimensions()

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

function M.update_window_dimensions()
	width = math.floor(vim.o.columns * 0.75)
	height = math.floor(vim.o.lines * 0.5)
end

function M.close_window()
	vim.api.nvim_win_close(file_list_win, true)
end

function M.redraw_window(search_string)
	local cursor_pos = vim.api.nvim_win_get_cursor(file_list_win)

	-- Clear the buffers
	vim.api.nvim_buf_set_lines(file_list_buf, 0, -1, false, {})
	option_per_line = {}

	local list_entries = M.get_entries_from_files(files)
	local sorted_file_names = {}
	for k in pairs(list_entries) do
		table.insert(sorted_file_names, k)
	end

	table.sort(sorted_file_names, function(a, b)
		return a:lower() < b:lower()
	end)

	local current_line = 1
	local drew_first_line = false
	for _, file in ipairs(sorted_file_names) do
		local lines = list_entries[file]
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
			local is_selected = M.get_selected_state(file, line_number)

			local line = "  " .. match_entry
			if is_selected then
				line = "*" .. string.sub(line, 2)
			end

			file_ops.set_highlighted_text(file_list_buf, current_line, line, search_string)

			current_line = current_line + 1
			option_per_line[current_line] = { file = file, line_number = line_number }
		end
		::continue::
	end

	vim.api.nvim_win_set_cursor(file_list_win, cursor_pos)
end

function M.make_buffer_readonly()
    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function M.show_no_matches(search_string)
	vim.api.nvim_buf_set_lines(file_list_buf, 0, -1, false, { "No matches found for '" .. search_string .. "'" })
end

function M.get_entries_from_files(file_list)
	local list_entries = {}
	for _, entry in ipairs(file_list) do
		local file, line_number, match_text = string.match(entry, "(.+):(%d+):(.+)")
		if file and line_number and match_text then
			if not list_entries[file] then
				list_entries[file] = {}
			end

			list_entries[file][line_number .. ": " .. match_text] = ""
		end
	end

	return list_entries
end

function M.get_selected_state(file, line_number)
	for _, v in pairs(selected_options) do
		if v.file == file and v.line_number == line_number then
			return true
		end
	end

	return false
end

function M.set_selected_state(file, line_number, selected)
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
			table.insert(selected_options, { file = file, line_number = line_number })
		end
	end
end

function M.clear_selected_state()
    selected_options = {}
end

function M.toggle_mark(search_string)
	vim.api.nvim_buf_set_option(file_list_buf, "modifiable", true)

	local line = vim.fn.line(".")
	local line_text = vim.fn.getline(line)

	if utils.is_line_number(line_text) then
		local was_marked = utils.is_line_marked(line_text)
		local updated_line = utils.get_marked_line(line_text, not was_marked)
		local option = option_per_line[line + 1]
		M.set_selected_state(option.file, option.line_number, not was_marked)
		file_ops.set_highlighted_text(file_list_buf, line, updated_line, search_string)
    else
        M.toggle_mark_all_in_file(search_string)
	end

	vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function M.collapse_file(search_string)
    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", true)

    local line = vim.fn.line('.')
    local line_text = vim.fn.getline(line)

    local file_name = nil
    if utils.is_line_number(line_text) then
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

    M.redraw_window(search_string)

    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function M.toggle_mark_all_in_file(search_string)
    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", true)

    local line = vim.fn.line('.')
    local line_text = vim.fn.getline(line)

    local was_marked = marked_files[line_text] ~= nil
    if was_marked then
        marked_files[line_text] = nil
    else
        marked_files[line_text] = true
    end

    if not utils.is_line_number(line_text) then
        local start_line = line + 1
        local end_line = start_line

        while vim.fn.getline(end_line) do
            local current_end_line = vim.fn.getline(end_line)
            if not utils.is_line_number(current_end_line) then
                break
            end

            end_line = end_line + 1
        end

        for i = start_line, end_line - 1 do
            local option = option_per_line[i + 1]
            M.set_selected_state(option.file, option.line_number, not was_marked)

            local tmp_line_text = vim.fn.getline(i)
            local new_line_text = utils.get_marked_line(tmp_line_text, not was_marked)
            file_ops.set_highlighted_text(file_list_buf, i, new_line_text, search_string)
        end
    end

    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function M.toggle_mark_all(search_string)
    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", true)

    all_files_marked = not all_files_marked

    for i = 1, vim.fn.line('$') do
        local line_text = vim.fn.getline(i)
        if utils.is_line_number(line_text) then
            local option = option_per_line[i + 1]
            M.set_selected_state(option.file, option.line_number, all_files_marked)

            local new_line_text = utils.get_marked_line(line_text, all_files_marked)
            file_ops.set_highlighted_text(file_list_buf, i, new_line_text, search_string)
        end
    end

    vim.api.nvim_buf_set_option(file_list_buf, "modifiable", false)
end

function M.get_width()
    return width
end

function M.get_buffer()
    return file_list_buf
end

function M.get_selected_options()
    return selected_options
end

function M.set_files(new_files)
    files = new_files
end

return M
