local M = {}

local default_keybinds = {
	toggle_mark = "x",
	toggle_collapse = "c",
	toggle_mark_all = "a",
	confirm_replace = "<CR>",
	cancel_replace = "<Esc>",
}

local keybinds = {}

function M.setup(config_keybinds)
	keybinds = config_keybinds or default_keybinds
end

function M.set_keybinds(file_list_buf, files, search_string)
	local toggle_mark_cmd = ":lua require('rip.window').toggle_mark('" .. search_string .. "')<CR>"
	local toggle_collapse_cmd = ":lua require('rip.window').collapse_file('" .. search_string .. "')<CR>"
	local toggle_mark_all_cmd = ":lua require('rip.window').toggle_mark_all('" .. search_string .. "')<CR>"
	local confirm_replace_cmd = ":lua require('rip.search').submit_window()<CR>"
	local cancel_replace_cmd = ":lua require('rip.window').close_window()<CR>"
	local opts = { noremap = true, silent = true }

	if #files > 0 then
		vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["toggle_mark"], toggle_mark_cmd, opts)
		vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["toggle_collapse"], toggle_collapse_cmd, opts)
		vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["toggle_mark_all"], toggle_mark_all_cmd, opts)
	end

	vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["confirm_replace"], confirm_replace_cmd, opts)
	vim.api.nvim_buf_set_keymap(file_list_buf, "n", keybinds["cancel_replace"], cancel_replace_cmd, opts)
end

return M
