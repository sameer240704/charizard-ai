local M = {}

-- Plugin state
M._initialized = false

-- Core modules
local state = require("ai-assist.core.state")
local factory = require("ai-assist.models.factory")
local window = require("ai-assist.ui.window")
local input = require("ai-assist.ui.input")
local utils = require("ai-assist.core.utils")
local db = require("ai-assist.core.database")

-- Setup function called by user
function M.setup(opts)
	if M._initialized then
		return
	end

	-- Merge user config with defaults
	local config = require("ai-assist.core.config")
	if opts then
		config = vim.tbl_deep_extend("force", config, opts)
		require("ai-assist.core.config").user_config = config
	end

	-- Initialize core components
	state.setup()

	-- Setup UI components
	window.setup()
	input.setup()

	-- Setup syntax highlighting
	require("ai-assist.ui.syntax").setup()

	-- Setup theme
	require("ai-assist.ui.theme").setup()

	-- Setup commands
	require("ai-assist.commands").setup()

	-- Setup keymaps if enabled
	if config.keymaps ~= false then
		require("ai-assist.keymaps").setup()
	end

	M._initialized = true

	-- Show initialization message
	vim.notify("AI Assistant initialized with model: " .. state.selected_model, vim.log.levels.INFO)
end

-- Main query processing function
function M.process_query(prompt)
	if not M._initialized then
		vim.notify("AI Assistant not initialized. Call setup() first.", vim.log.levels.ERROR)
		return
	end

	if not prompt or prompt:match("^%s*$") then
		vim.notify("Empty prompt provided", vim.log.levels.WARN)
		return
	end

	-- Set loading state
	state.loading = true

	-- Create/show window
	window.create_window()

	-- Add query to display
	local config = require("ai-assist.core.config")
	local query_lines = {
		"",
		config.ui.prompt_prefix .. prompt,
		"",
		"Processing...",
		"",
	}
	window.append_lines(query_lines)

	-- Process query asynchronously
	vim.schedule(function()
		local response, err = factory.query(state.selected_model, prompt, state.context_files)

		state.loading = false

		if err then
			window.append_lines({
				"❌ Error: " .. err,
				"",
			})
			vim.notify("AI query failed: " .. err, vim.log.levels.ERROR)
			return
		end

		if not response or response == "" then
			window.append_lines({
				"❌ No response received",
				"",
			})
			return
		end

		-- Format and display response
		local response_lines = utils.format_response(response, config.ui.response_prefix)

		-- Replace "Processing..." line
		local buf_lines = vim.api.nvim_buf_get_lines(window.buf, 0, -1, false)
		for i, line in ipairs(buf_lines) do
			if line == "Processing..." then
				vim.api.nvim_buf_set_lines(window.buf, i - 1, i, false, response_lines)
				break
			end
		end

		-- Add to history
		if state.current_session then
			db.add_history(state.current_session, prompt, response)
		end
	end)
end

-- Query with current selection
function M.query_selection(prompt_template)
	local selection = utils.get_visual_selection()

	if selection == "" then
		vim.notify("No text selected", vim.log.levels.WARN)
		return
	end

	local prompt = prompt_template and string.format(prompt_template, selection) or selection

	M.process_query(prompt)
end

-- Query with current buffer
function M.query_buffer(prompt_template)
	local content = utils.get_current_buffer_content()

	if content == "" then
		vim.notify("Buffer is empty", vim.log.levels.WARN)
		return
	end

	local prompt = prompt_template and string.format(prompt_template, content) or content

	M.process_query(prompt)
end

-- Toggle main window
function M.toggle()
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

-- Add context from current buffer
function M.add_current_buffer()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		vim.notify("No current buffer to add", vim.log.levels.WARN)
		return false
	end

	return state.add_context(filepath)
end

-- Quick code explanation
function M.explain_code()
	M.query_selection("Please explain this code:\n\n%s")
end

-- Quick code review
function M.review_code()
	M.query_selection("Please review this code and suggest improvements:\n\n%s")
end

-- Quick code optimization
function M.optimize_code()
	M.query_selection("Please optimize this code for better performance and readability:\n\n%s")
end

-- Get plugin status
function M.status()
	if not M._initialized then
		return {
			initialized = false,
			error = "Plugin not initialized",
		}
	end

	return {
		initialized = true,
		model = state.selected_model,
		session = state.current_session,
		context_files = #state.context_files,
		loading = state.loading,
		window_open = window.win and vim.api.nvim_win_is_valid(window.win) or false,
	}
end

-- Health check
function M.health()
	local health = {
		plugin_initialized = M._initialized,
		models = factory.health_check(),
		database_connected = pcall(function()
			return db.db ~= nil
		end),
		context_files = #state.context_files,
	}

	-- Check for common issues
	health.issues = {}

	if not health.plugin_initialized then
		table.insert(health.issues, "Plugin not initialized - call require('ai-assist').setup()")
	end

	if not health.database_connected then
		table.insert(health.issues, "Database connection failed")
	end

	local available_models = 0
	for _, model_health in pairs(health.models) do
		if model_health.available then
			available_models = available_models + 1
		end
	end

	if available_models == 0 then
		table.insert(health.issues, "No models available")
	end

	return health
end

-- Expose commonly used modules
M.state = state
M.config = require("ai-assist.core.config")
M.models = factory
M.utils = utils
M.db = db

return M
