# rip.nvim

Just replace all your problems away

## What do I do?

Sometimes we need to replace a string with another in all files in a project. This plugin aims to make this process easier by providing a nice UI to select occurences and choose which ones to replace and which to keep.

<p align="center">
    <img src="https://i.imgur.com/4wyFE48.gif" width="800">
</p>

<p align="center">
    <em>Simple example of the plugin in action!</em>
</p>

## How do you install me?

Using `Lazy` it is as simple as adding the following to your configuration

```lua
return {
    "lucaspellegrinelli/rip.nvim",
    config = function()
        local rip = require("rip")
        rip.setup({}) -- Required

        vim.keymap.set("n", "<leader>rp", rip.replace_in_project, {})
        vim.keymap.set("n", "<leader>rg", rip.replace_in_git, {})
    end
}
```

With this you can probably figure out how to install it with your chosen plugin manager.

## How do you configure me?

### Keybinds for starting the plugin

To specify how to start the replacing process, you can edit the `keymaps` like so

```lua
vim.keymap.set('n', '<leader>rp', require("rip").replace_in_project, {})
vim.keymap.set('n', '<leader>rg', require("rip").replace_in_git, {})
```

The `replace_in_project` function replaces the target string in all files of your project while the `replace_in_git` function replaces the target string in all git tracked files in your project

### Setup configurations

For editing other configurations you can pass a `config` table to the `setup` function. These are the default values:

```lua
local rip = require("rip")

rip.setup({
    keybinds = {
        toggle_mark = "x", -- (Un)Selecting a specific occurences or files to be replaced
        toggle_collapse = "c", -- (Un)Collapsing the occurences of a specific file
        toggle_mark_all = "a", -- (Un)Selecting all the occurences found in all files
        confirm_replace = "<CR>", -- Close the window and replacing all selected occurences
        cancel_replace = "<Esc>", -- Close the window and NOT replacing any occurences
    },
    window = {
        highlight_color = "#e9b565", -- Color of the matched string in the popup
    }
})
```
