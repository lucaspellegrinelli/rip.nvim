local utils = require("rip.utils")
local window = require("rip.window")

local function get_user_inputs()
    local search_string = vim.fn.input("Search: ")

    if search_string == "" then
        return false, nil, nil
    end

    -- Leaving the replace string empty is a valid input since the user might
    -- want to delete the search string
    local replace_string = vim.fn.input("Replace: ")

    return true, search_string, replace_string
end

local function replace_in_project_generic(files_searched, search_string, replace_string)
    local files = {}

    for line in string.gmatch(files_searched, "[^\r\n]+") do
        local file, line_number, match_text = string.match(line, "(.+):(%d+):(.+)")
        if file then
            match_text = match_text:gsub("^%s+", "")
            match_text = utils.trim_to_word(match_text, search_string, window.config.width() - 10)
            table.insert(files, file .. ":" .. line_number .. ":" .. match_text)
        end
    end

    window.reset_state({
        matched_files = files,
        searched_string = search_string,
        replace_string = replace_string,
    })

    window.build_window()
    window.redraw_window()
end

local function replace_in_project()
    local success, search_string, replace_string = get_user_inputs()

    if not success or not search_string then
        vim.cmd("echo ''")
        return
    end

    local searched_files = vim.fn.system("find . -type f -exec grep -n -H -e '" .. search_string .. "' {} +")
    replace_in_project_generic(searched_files, search_string, replace_string)
end

local function replace_in_git()
    local success, search_string, replace_string = get_user_inputs()

    if not success or not search_string then
        vim.cmd("echo ''")
        return
    end

    local searched_files = vim.fn.system("git ls-files | xargs grep -n -H -e '" .. search_string .. "'")
    replace_in_project_generic(searched_files, search_string, replace_string)
end

return {
    replace_in_project = replace_in_project,
    replace_in_git = replace_in_git,
}
