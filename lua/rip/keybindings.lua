local M = {}

local default_keybinds = {
	toggle_mark = "x",
	toggle_collapse = "c",
	toggle_mark_all = "a",
	confirm_replace = "<CR>",
	cancel_replace = "<Esc>",
}

M.keybinds = {}

function M.setup(config_keybinds)
	M.keybinds = config_keybinds or default_keybinds
end

function M.set_keybinds(buffer, bind_all)
	local toggle_mark_cmd = ":lua require('rip.actions').toggle_mark()<CR>"
	local toggle_collapse_cmd = ":lua require('rip.actions').collapse_file()<CR>"
	local toggle_mark_all_cmd = ":lua require('rip.actions').toggle_mark_all()<CR>"
	local confirm_replace_cmd = ":lua require('rip.actions').submit_changes()<CR>"
	local cancel_replace_cmd = ":lua require('rip.actions').close_window()<CR>"
	local opts = { noremap = true, silent = true }

	if bind_all then
		vim.api.nvim_buf_set_keymap(buffer, "n", M.keybinds["toggle_mark"], toggle_mark_cmd, opts)
		vim.api.nvim_buf_set_keymap(buffer, "n", M.keybinds["toggle_collapse"], toggle_collapse_cmd, opts)
		vim.api.nvim_buf_set_keymap(buffer, "n", M.keybinds["toggle_mark_all"], toggle_mark_all_cmd, opts)
	end

	vim.api.nvim_buf_set_keymap(buffer, "n", M.keybinds["confirm_replace"], confirm_replace_cmd, opts)
	vim.api.nvim_buf_set_keymap(buffer, "n", M.keybinds["cancel_replace"], cancel_replace_cmd, opts)
end

return M
