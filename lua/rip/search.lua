local utils = require("rip.utils")
local file_ops = require("rip.file_ops")
local window = require("rip.window")
local keybindings = require("rip.keybindings")

local search_string = ""
local replace_string = ""

local files = {}

local function replace_in_project_generic(files_searched)
	files = {}
    window.clear_selected_state()

	for line in string.gmatch(files_searched, "[^\r\n]+") do
		local file, line_number, match_text = string.match(line, "(.+):(%d+):(.+)")
		if file then
			match_text = match_text:gsub("^%s+", "")
			match_text = utils.trim_to_word(match_text, search_string, window.get_width() - 10)
			table.insert(files, file .. ":" .. line_number .. ":" .. match_text)
		end
	end

	window.set_files(files)
	window.build_window()
	window.redraw_window(search_string)

    if #files == 0 then
		window.show_no_matches(search_string)
    end

    keybindings.set_keybinds(window.get_buffer(), files, search_string)
    window.make_buffer_readonly()
end

local function replace_in_project()
	local success, new_search_string, new_replace_string = file_ops.get_user_inputs()

	if not success or not new_search_string then
		vim.cmd("echo ''")
		return
	end

	search_string = new_search_string
	replace_string = new_replace_string or replace_string
	local searched_files = vim.fn.system("find . -type f -exec grep -n -H -e '" .. search_string .. "' {} +")
	replace_in_project_generic(searched_files)
end

local function replace_in_git()
	local success, new_search_string, new_replace_string = file_ops.get_user_inputs()

	if not success or not new_search_string then
		vim.cmd("echo ''")
		return
	end

	search_string = new_search_string
	replace_string = new_replace_string or replace_string
	local searched_files = vim.fn.system("git ls-files | xargs grep -n -H -e '" .. search_string .. "'")
	replace_in_project_generic(searched_files)
end

local function submit_window()
    local selected_options = window.get_selected_options()
	if #selected_options > 0 then
        file_ops.submit_changes(selected_options, search_string, replace_string)
	end

    window.close_window()
end

return {
	replace_in_project = replace_in_project,
	replace_in_git = replace_in_git,
	submit_window = submit_window,
}
