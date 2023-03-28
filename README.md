# Replace In Project - NeoVim Plugin

## What do I do?

Replace a string with another in all files in a project (or just the git tracked files!)

## How do you install me?

Using `Packer` it is as simple as adding the following line to your Packer configuration file

```use("lucaspellegrinelli/rip.nvim")```

With this you can probably figure out how to install it with your chosen plugin manager.

## How do you configure me?

You can add the following lines to a lua file in your configuration to specify the keybinds to open the utility

```lua
local rip = require("rip")

vim.keymap.set('n', '<leader>rp', rip.replace_in_project, {})
vim.keymap.set('n', '<leader>rg', rip.replace_in_git, {})
```

The `replace_in_project` function replaces the target string in all files of your project while the `replace_in_git` function replaces the target string in all git tracked files in your project

Along with defining the keybindings for opening the utility, you can also configure the shortcuts inside the utility like

```lua
local rip = require("rip")

rip.setup({
    keybinds = {
        toggle_mark = "y",
        toggle_collapse = "l",
        toggle_mark_all_in_file = "p",
    },
})
```

In the example above, we replaced some of the shortcuts the utility has (like replacing the toggle marked file from `x` to `y`). The possible actions to configure are:

```
X. key_binding_key (default_value) - Description

1. toggle_mark (x) - Selecting/Unselecting a specific occurence to be replaced
2. toggle_collapse (c) - Collapsing/Uncollapsing the occurences of a specific file
3. toggle_mark_all_in_file (a) - Selecting/Unselecting all the occurences in a specific file
4. confirm_replace (<CR>) - Close the window and replacing all selected occurences
5. cancel_replace (<Esc>) - Close the window and NOT replacing any occurences
```
