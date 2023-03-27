-- Call git ls-files and store the files in a variable

local files = {}

for line in io.popen("git ls-files"):lines() do
    table.insert(files, line)
end

-- Print the files
for _, file in ipairs(files) do
    print(file)
end
