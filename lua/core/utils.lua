local M = {}

-- HTTP Request function with timeout and better error handling
function M.http_request(url, method, headers, body, timeout)
	timeout = timeout or 10
	local cmd = string.format("curl -s -X %s -m %d", method, timeout)

	-- Add headers
	for k, v in pairs(headers or {}) do
		cmd = cmd .. string.format(" -H '%s: %s'", k, v)
	end

	-- Add body if present
	if body and (method == "POST" or method == "PUT") then
		cmd = cmd .. string.format(" -d '%s'", vim.fn.shellescape(body))
	end

	-- Add URL and capture both stdout and stderr
	cmd = cmd .. " " .. url .. " 2>&1"

	local handle = io.popen(cmd)
	if not handle then
		return nil, "Failed to execute curl command"
	end

	local response = handle:read("*a")
	handle:close()

	-- Check for curl errors
	if response:match("curl: %(%d+%)") then
		return nil, "Curl error: " .. response
	end

	-- Try to parse the JSON
	local ok, json = pcall(vim.json.decode, response)
	if ok then
		return json
	end

	return nil, "Unexcepted response: " .. response
end

-- Check if Ollama is running (multiple methods)
function M.check_ollama_running()
	local ok, _ = pcall(function()
		local resp = M.http_request("http://localhost:11434", "GET", {}, nil, 2)
		return resp ~= nil
	end)

	if ok then
		return true
	end

	-- Check process status
	local handle = io.popen("pgrep -f 'ollama serve' 2>/dev/null")

	if handle then
		local result = handle:read("*a")
		handle:close()
		return result ~= ""
	end

	return false
end

-- Get visual selection from current buffer
function M.get_visual_selection()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

	if #lines == 0 then
		return ""
	end

	-- Handles single line selection
	if #lines == 1 then
		return string.sub(lines[1], start_pos[3], end_pos[3])
	end

	-- Handles multi-line selection
	lines[1] = string.sub(lines[1], start_pos[3])
	lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
	return table.concat(lines, "\n")
end

-- Get current buffer content
function M.get_current_buffer_content()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	return table.concat(lines, "\n")
end

-- Format response with proper indentation and prefixes
function M.format_response(response, prefix)
	prefix = prefix or "  "

	if not response or response == "" then
		return { "No reponse received" }
	end

	local lines = vim.split(response, "\n")
	local formatted = {}

	for i, line in ipairs(lines) do
		if i == 1 then
			table.insert(formatted, line)
		else
			table.insert(formatted, prefix .. line)
		end
	end

	return formatted
end

-- Create a spinner animation for loading states
function M.create_spinner()
	local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
	local i = 1
	return {
		next = function()
			i = (i % #frames) + 1
			return frames[i]
		end,
	}
end

-- Validates file path and reads content
function M.read_file_safely(filepath)
	local ok, content = pcall(vim.fn.readfile, filepath)

	if not ok or not content then
		return nil, "Failed to read file: " .. filepath
	end

	return table.concat(content, "\n")
end

-- Extract filename from path
function M.get_filename(filepath)
	return filepath:match("([^/\\]+)$") or "untitled"
end

function M.file_to_base64(filepath)
    local file = io.open(filepath, "rb")
    if not file then return nil end

    local content = file:read("*a")
    file:close()
    return vim.base64.encode(content)
end

-- Get MIME type from filename 
-- TODO: For future multi-modal support
function M.get_mime_type(filename)
  if filename:match("%.png$") then
    return "image/png"
  elseif filename:match("%.jpe?g$") then
    return "image/jpeg"
  elseif filename:match("%.pdf$") then
    return "application/pdf"
  end
  return "text/plain"
end

-- Throttle function to limit API calls
function M.throttle(func, delay)
  local last = 0
  return function(...)
    local now = os.time()
    if now - last >= delay then
      last = now
      return func(...)
    end
  end
end

-- Simple markdown to ansi conversion for terminal display
function M.markdown_to_ansi(text)
  -- Basic conversions (can be expanded)
  return text
    :gsub("```(.-)```", "\27[36m%1\27[0m") -- Code blocks
    :gsub("`(.-)`", "\27[36m%1\27[0m")     -- Inline code
    :gsub("%*%*(.-)%*%*", "\27[1m%1\27[0m") -- Bold
    :gsub("%*(.-)%*", "\27[3m%1\27[0m")     -- Italic
end

return M
