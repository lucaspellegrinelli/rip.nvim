local M = {}

function M.trim_to_word(str, target, max_len)
	if #str > max_len then
		local target_index = string.find(str, target)
		if target_index then
			local target_len = #target
			local trim_len = max_len - target_len - 1
			local start_trim = math.max(target_index - trim_len, 1)
			local end_trim = math.min(target_index + target_len + trim_len - 1, #str)

			str = string.sub(str, start_trim, end_trim)

			if start_trim > 1 then
				str = "..." .. string.sub(str, start_trim)
			end

			if end_trim < #str then
				str = string.sub(str, 1, -4) .. "..."
			end
		else
			str = string.sub(str, 1, max_len - 3) .. "..."
		end
	end

	return str
end

function M.is_line_number(line)
	return string.sub(line, 1, 1) == "*" or string.sub(line, 1, 1) == " "
end

function M.is_line_marked(line)
	return string.sub(line, 1, 1) == "*"
end

function M.get_marked_line(line, marked)
	if marked then
		return "*" .. string.sub(line, 2)
	else
		return " " .. string.sub(line, 2)
	end
end

return M
