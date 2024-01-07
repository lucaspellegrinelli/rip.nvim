local keybindings = require("rip.keybindings")
local utils = require("rip.utils")

local M = {}

M.state = {
	window = nil, -- Window ID
	buffer = nil, -- Buffer ID
	searched_string = "", -- String that was searched for
	replace_string = "", -- String that will replace the searched string
	matched_files = {}, -- Array of strings (file:line_number:match_text)
	selected_items = {}, -- Array of { file : str, line_number : int }
	item_in_line = {}, -- Array of { file : str, line_number : int }
	collapsed_files = {}, -- Array of { file : bool | nil }
	marked_files = {}, -- Array of { file : bool | nil }
}

M.config = {
	highlight_color = "#e9b565",
	width = function()
		return math.floor(vim.o.columns * 0.75)
	end,
	height = function()
		return math.floor(vim.o.lines * 0.5)
	end,
}

function M.setup(config)
	config = config or {}

	for k, v in pairs(config) do
		if v ~= nil then
			M.config[k] = v
		end
	end

	vim.cmd("highlight HighlightedSearchColor guifg=" .. M.config.highlight_color)
end

function M.build_window()
	local width, height = M.config.width(), M.config.height()

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

	M.state.buffer = vim.api.nvim_create_buf(false, true)
	M.state.window = vim.api.nvim_open_win(M.state.buffer, true, file_list_opts)
end

function M.redraw_window()
	if #M.state.matched_files == 0 then
		local message = "No matches found for '" .. M.state.searched_string .. "'"
		vim.api.nvim_buf_set_lines(M.state.buffer, 0, -1, false, { message })
		return
	end

	local cursor_pos = vim.api.nvim_win_get_cursor(M.state.window)

	-- Clear the buffers
	vim.api.nvim_buf_set_lines(M.state.buffer, 0, -1, false, {})
	M.state.item_in_line = {}

	local list_entries = M.get_entries_from_files(M.state.matched_files)
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
		vim.api.nvim_buf_set_lines(M.state.buffer, line_to_draw, -1, false, { file })
		current_line = current_line + 1
		drew_first_line = true

		if M.state.collapsed_files[file] then
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

			M.set_highlighted_text(current_line, line)

			current_line = current_line + 1
			M.state.item_in_line[current_line] = { file = file, line_number = line_number }
		end
		::continue::
	end

	keybindings.set_keybinds(M.state.buffer, #M.state.matched_files > 0)
	vim.api.nvim_win_set_cursor(M.state.window, cursor_pos)
	vim.api.nvim_buf_set_option(M.state.buffer, "modifiable", true)
end

function M.close_window()
	vim.api.nvim_win_close(M.state.window, true)
	vim.api.nvim_buf_delete(M.state.buffer, { force = true })
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

function M.toggle_mark_all_in_file()
	vim.api.nvim_buf_set_option(M.state.buffer, "modifiable", true)

	local line = vim.fn.line(".")
	local line_text = vim.fn.getline(line)

	local was_marked = M.state.marked_files[line_text] ~= nil
	if was_marked then
		M.state.marked_files[line_text] = nil
	else
		M.state.marked_files[line_text] = true
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
			local option = M.state.item_in_line[i + 1]
			M.set_selected_state(option.file, option.line_number, not was_marked)

			local tmp_line_text = vim.fn.getline(i)
			local new_line_text = utils.get_marked_line(tmp_line_text, not was_marked)
			M.set_highlighted_text(i, new_line_text)
		end
	end

	vim.api.nvim_buf_set_option(M.state.buffer, "modifiable", false)
end

function M.set_highlighted_text(line, text)
	vim.api.nvim_buf_set_lines(M.state.buffer, line - 1, line, false, { text })
	local target_text = M.state.searched_string
	local match_start, match_end = string.find(text, target_text)
	if match_start then
		vim.api.nvim_buf_add_highlight(
			M.state.buffer,
			0,
			"HighlightedSearchColor",
			line - 1,
			match_start - 1,
			match_end
		)
	end
end

function M.get_selected_state(file, line_number)
	for _, v in pairs(M.state.selected_items) do
		if v.file == file and v.line_number == line_number then
			return true
		end
	end

	return false
end

function M.set_selected_state(file, line_number, selected)
	local already_selected_idx = nil
	for k, v in pairs(M.state.selected_items) do
		if v.file == file and v.line_number == line_number then
			already_selected_idx = k
			break
		end
	end

	if already_selected_idx then
		if not selected then
			M.state.selected_items[already_selected_idx] = nil
		end
	else
		if selected then
			table.insert(M.state.selected_items, { file = file, line_number = line_number })
		end
	end
end

function M.reset_state(new_state)
	M.state = {
		window = nil,
		buffer = nil,
		searched_string = "",
		replace_string = "",
		matched_files = {},
		selected_items = {},
		item_in_line = {},
		collapsed_files = {},
		marked_files = {},
	}

    for k, v in pairs(new_state) do
        M.state[k] = v
    end
end

function M.set_matched_files(files)
	M.state.matched_files = files
end

function M.set_search_string(search_string, replace_string)
	M.state.searched_string = search_string
	M.state.replace_string = replace_string
end

return M
