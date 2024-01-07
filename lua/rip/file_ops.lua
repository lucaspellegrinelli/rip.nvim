local M = {}

function M.get_user_inputs()
	local search_string = vim.fn.input("Search: ")

	if search_string == "" then
		return false, nil, nil
	end

	local replace_string = vim.fn.input("Replace: ")

	if replace_string == "" then
		-- Leaving the replace string empty is a valid input since the user might
		-- want to delete the search string
		return true, search_string, nil
	end

	return true, search_string, replace_string
end

function M.submit_changes(selected_options, search_string, replace_string)
	local current_file = vim.fn.expand("%:p")
	if current_file ~= "" then
		vim.cmd("write")
	end

	for _, v in pairs(selected_options) do
		local file = v.file
		local line_number = v.line_number

		local file_contents = vim.fn.readfile(file)
		local line = file_contents[line_number]
		local new_line = line:gsub(search_string, replace_string)
		file_contents[line_number] = new_line
		vim.fn.writefile(file_contents, file)
	end

	if current_file ~= "" then
		vim.cmd("edit!")
	end
end

function M.set_highlighted_text(buffer, line, text, highlighted_text)
	vim.api.nvim_buf_set_lines(buffer, line - 1, line, false, { text })
	local match_start, match_end = string.find(text, highlighted_text)
	if match_start then
		vim.api.nvim_buf_add_highlight(buffer, 0, "HighlightedSearchColor", line - 1, match_start - 1, match_end)
	end
end

return M
