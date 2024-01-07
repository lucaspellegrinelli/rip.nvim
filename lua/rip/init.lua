local keybindings = require("rip.keybindings")
local search = require("rip.search")
local window = require("rip.window")

local M = {}

function M.setup(config)
    config = config or {}
    keybindings.setup(config.keybinds)
    window.setup(config.window)
end

M.replace_in_project = search.replace_in_project
M.replace_in_git = search.replace_in_git
M.submit_window = search.submit_window

return M
