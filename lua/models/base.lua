local M = {}
local utils = require("ai-assist.core.utils")

-- Base model metatable
M.BaseModel = {}

function M.BaseModel:new(config)
	local obj = {
		config = config or {},
		type = config.type or "unknown",
		name = config.name or "Unnamed Model",
	}
	setmetatable(obj, { __index = self })
	return obj
end

-- To be implemented by concrete models
function M.BaseModel:query(prompt, context)
	error("Abstract method 'query' must be implemented by child classes")
end

-- Common health check method
function M.BaseModel:health_check()
	if self.type == "ollama" then
		return utils.check_ollama_running()
	end
	return true -- Remote models assumed always available
end

-- Common context formatting
function M.BaseModel:format_context(context_files)
	if not context_files or #context_files == 0 then
		return ""
	end

	local context = { "Context files:" }
	for _, file in ipairs(context_files) do
		table.insert(context, string.format("\nFile: %s\n%s", file.name, file.content))
	end
	return table.concat(context, "\n")
end

-- Common response cleaning
function M.BaseModel:clean_response(response)
	if not response then
		return ""
	end
	-- Remove common artifacts
	return response:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\n+", "\n")
end

return M
