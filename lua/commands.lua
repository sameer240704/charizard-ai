local M = {}
local state = require("ai-assist.core.state")
local factory = require("ai-assist.models.factory")
local window = require("ai-assist.ui.window")
local input = require("ai-assist.ui.input")
local utils = require("ai-assist.core.utils")

-- Main query command
local function ai_ask(opts)
	local prompt = opts.args or ""

	if prompt == "" then
		-- Open input window if no prompt provided
		window.create_window()
		input.create_window()
		return
	end

	require("ai-assist").process_query(prompt)
end

-- Add context file command
local function ai_add_context(opts)
	local filepath = opts.args

	if not filepath or filepath == "" then
		filepath = vim.fn.expand("%:p")
		if filepath == "" then
			vim.notify("No file specified and no current buffer", vim.log.levels.WARN)
			return
		end
	end

	-- Expand relative paths
	filepath = vim.fn.fnamemodify(filepath, ":p")

	if not vim.fn.filereadable(filepath) then
		vim.notify("File not readable: " .. filepath, vim.log.levels.ERROR)
		return
	end

	local success = state.add_context(filepath)
	if success then
		local filename = utils.get_filename(filepath)
		vim.notify("Added context: " .. filename, vim.log.levels.INFO)
	else
		vim.notify("Failed to add context file", vim.log.levels.ERROR)
	end
end

-- Clear context command
local function ai_clear_context()
	state.clear_context()
	vim.notify("Context cleared", vim.log.levels.INFO)
end

-- List context files command
local function ai_list_context()
	if #state.context_files == 0 then
		vim.notify("No context files added", vim.log.levels.INFO)
		return
	end

	local files = {}
	for i, file in ipairs(state.context_files) do
		table.insert(files, string.format("%d. %s (%s)", i, file.name, file.path))
	end

	vim.notify("Context files:\n" .. table.concat(files, "\n"), vim.log.levels.INFO)
end

-- Model selection command
local function ai_model(opts)
	local model_name = opts.args

	if not model_name or model_name == "" then
		-- Show interactive selection
		factory.select_model(function(selected_model)
			if state.set_model(selected_model) then
				vim.notify("Switched to model: " .. selected_model, vim.log.levels.INFO)
			end
		end)
		return
	end

	if state.set_model(model_name) then
		vim.notify("Switched to model: " .. model_name, vim.log.levels.INFO)
	else
		vim.notify("Invalid model: " .. model_name, vim.log.levels.ERROR)
	end
end

-- List available models command
local function ai_models()
	local models = factory.list_models()
	local config = require("ai-assist.core.config")
	local current = state.selected_model

	local list = {}
	for _, name in ipairs(models) do
		local model_config = config.models[name]
		local indicator = (name == current) and " (current)" or ""
		table.insert(list, string.format("%s %s%s", model_config.icon, model_config.name, indicator))
	end

	vim.notify("Available models:\n" .. table.concat(list, "\n"), vim.log.levels.INFO)
end

-- Health check command
local function ai_health()
	local results = factory.health_check()
	local status = {}

	for name, result in pairs(results) do
		local config = require("ai-assist.core.config").models[name]
		local status_icon = result.available and "✓" or "✗"
		table.insert(status, string.format("%s %s %s (%s)", status_icon, config.icon, config.name, result.type))
	end

	vim.notify("Model Health Check:\n" .. table.concat(status, "\n"), vim.log.levels.INFO)
end

-- Query with selection command
local function ai_explain()
	local selection = utils.get_visual_selection()
	if selection == "" then
		selection = utils.get_current_buffer_content()
	end

	if selection == "" then
		vim.notify("No text to explain", vim.log.levels.WARN)
		return
	end

	local prompt = "Please explain this code:\n\n" .. selection
	require("ai-assist").process_query(prompt)
end

-- Code review command
local function ai_review()
	local selection = utils.get_visual_selection()
	if selection == "" then
		selection = utils.get_current_buffer_content()
	end

	if selection == "" then
		vim.notify("No code to review", vim.log.levels.WARN)
		return
	end

	local prompt = "Please review this code and suggest improvements:\n\n" .. selection
	require("ai-assist").process_query(prompt)
end

-- Optimize code command
local function ai_optimize()
	local selection = utils.get_visual_selection()
	if selection == "" then
		selection = utils.get_current_buffer_content()
	end

	if selection == "" then
		vim.notify("No code to optimize", vim.log.levels.WARN)
		return
	end

	local prompt = "Please optimize this code for better performance and readability:\n\n" .. selection
	require("ai-assist").process_query(prompt)
end

-- Show history command
local function ai_history()
	local history = state.get_history(10)
	if #history == 0 then
		vim.notify("No conversation history", vim.log.levels.INFO)
		return
	end

	window.create_window()
	window.clear()

	local lines = { "=== Recent Conversation History ===", "" }
	for i = #history, 1, -1 do -- Show most recent first
		local entry = history[i]
		table.insert(lines, "🧠 " .. entry.query)
		table.insert(lines, "")

		local response_lines = vim.split(entry.response, "\n")
		for _, line in ipairs(response_lines) do
			table.insert(lines, "🤖 " .. line)
		end

		table.insert(lines, "")
		table.insert(lines, string.rep("─", 50))
		table.insert(lines, "")
	end

	window.append_lines(lines)
end

-- Close/toggle command
local function ai_close()
	if window.win and vim.api.nvim_win_is_valid(window.win) then
		window.close()
		if input.win and vim.api.nvim_win_is_valid(input.win) then
			input.close()
		end
	else
		window.create_window()
		input.create_window()
	end
end

function M.setup()
	-- Main commands
	vim.api.nvim_create_user_command("AIAsk", ai_ask, {
		nargs = "*",
		desc = "Ask AI assistant a question",
	})

	vim.api.nvim_create_user_command("AIToggle", ai_close, {
		desc = "Toggle AI assistant window",
	})

	-- Context management
	vim.api.nvim_create_user_command("AIAddContext", ai_add_context, {
		nargs = "?",
		complete = "file",
		desc = "Add file to AI context",
	})

	vim.api.nvim_create_user_command("AIClearContext", ai_clear_context, {
		desc = "Clear AI context files",
	})

	vim.api.nvim_create_user_command("AIListContext", ai_list_context, {
		desc = "List current context files",
	})

	-- Model management
	vim.api.nvim_create_user_command("AIModel", ai_model, {
		nargs = "?",
		complete = function()
			return factory.list_models()
		end,
		desc = "Select AI model",
	})

	vim.api.nvim_create_user_command("AIModels", ai_models, {
		desc = "List available models",
	})

	vim.api.nvim_create_user_command("AIHealth", ai_health, {
		desc = "Check model availability",
	})

	-- Code assistance
	vim.api.nvim_create_user_command("AIExplain", ai_explain, {
		range = true,
		desc = "Explain selected code",
	})

	vim.api.nvim_create_user_command("AIReview", ai_review, {
		range = true,
		desc = "Review selected code",
	})

	vim.api.nvim_create_user_command("AIOptimize", ai_optimize, {
		range = true,
		desc = "Optimize selected code",
	})

	-- Utility commands
	vim.api.nvim_create_user_command("AIHistory", ai_history, {
		desc = "Show conversation history",
	})

	vim.api.nvim_create_user_command("AIClose", ai_close, {
		desc = "Close AI assistant windows",
	})
end

return M
