local M = {}

-- State variables
M.current_session = nil
M.context_files = {}
M.selected_model = nil
M.loading = false
M.db = nil

-- Safe require function with error handling
local function safe_require(module_name)
	local ok, module = pcall(require, module_name)
	if not ok then
		vim.notify("Failed to load module: " .. module_name .. " - " .. tostring(module), vim.log.levels.ERROR)
		return nil
	end
	return module
end

-- Initialize state for the usual setup
function M.setup()
	-- Try to load database module with error handling
	-- 	M.db = safe_require("ai-assist.core.database")
	local db_module_ok, db_module = pcall(require, "ai-assist.core.database")

	if db_module_ok and type(db_module) == "table" then
		M.db = db_module
		-- Initialize database connection
		local ok, err = pcall(M.db.setup)
		if not ok then
			vim.notify("Database setup failed: " .. tostring(err), vim.log.levels.WARN)
			M.db = M.create_fallback_db()
		end
	else
		vim.notify("Database module not available or invalid, using in-memory storage", vim.log.levels.WARN)
		M.db = M.create_fallback_db()
	end

	if not M.db then
		vim.notify("Database module not available, using in-memory storage", vim.log.levels.WARN)
		-- Fallback to in-memory storage
		M.db = M.create_fallback_db()
	elseif type(M.db) ~= "table" then
		vim.notify("Database module returned invalid type: " .. type(M.db), vim.log.levels.ERROR)
		M.db = M.create_fallback_db()
	end

	-- Initialize database connection
	if M.db and M.db.setup then
		local ok, err = pcall(M.db.setup)
		if not ok then
			vim.notify("Database setup failed: " .. tostring(err), vim.log.levels.WARN)
			M.db = M.create_fallback_db()
		end
	end

	-- Load config
	local config = safe_require("ai-assist.core.config")
	if config and config.default_model then
		M.selected_model = config.default_model
	else
		M.selected_model = "gemini" -- fallback default
		vim.notify("Using fallback default model: gemini", vim.log.levels.WARN)
	end

	-- Create initial session
	if M.db and M.db.create_session then
		local ok, session = pcall(M.db.create_session, M.selected_model)
		if ok then
			M.current_session = session
		else
			vim.notify("Failed to create session: " .. tostring(session), vim.log.levels.WARN)
			M.current_session = M.generate_session_id()
		end
	else
		M.current_session = M.generate_session_id()
	end

	vim.notify("AI Assistant state initialized successfully", vim.log.levels.INFO)
end

-- Create fallback database implementation
function M.create_fallback_db()
	local fallback_db = {}
	local sessions = {}
	local history = {}
	local context_files = {}

	function fallback_db.setup()
		-- No-op for in-memory storage
		return true
	end

	function fallback_db.create_session(model_name)
		local session_id = M.generate_session_id()
		sessions[session_id] = {
			id = session_id,
			model = model_name,
			created_at = os.time(),
		}
		history[session_id] = {}
		context_files[session_id] = {}
		return session_id
	end

	function fallback_db.add_context_file(session_id, file_info)
		if not context_files[session_id] then
			context_files[session_id] = {}
		end
		table.insert(context_files[session_id], file_info)
		return true
	end

	function fallback_db.update_context_files(session_id, files)
		context_files[session_id] = files or {}
		return true
	end

	function fallback_db.get_history(session_id, limit)
		if not history[session_id] then
			return {}
		end

		limit = limit or 20
		local session_history = history[session_id]
		local start_idx = math.max(1, #session_history - limit + 1)

		local result = {}
		for i = start_idx, #session_history do
			table.insert(result, session_history[i])
		end

		return result
	end

	function fallback_db.add_message(session_id, message)
		if not history[session_id] then
			history[session_id] = {}
		end
		table.insert(history[session_id], {
			content = message,
			timestamp = os.time(),
		})
		return true
	end

	return fallback_db
end

-- Generate a simple session ID
function M.generate_session_id()
	return "session_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- Add context file with improved error handling
function M.add_context(filepath)
	if not filepath or filepath == "" then
		vim.notify("Invalid filepath provided", vim.log.levels.WARN)
		return false
	end

	-- Check if file exists and is readable
	if vim.fn.filereadable(filepath) ~= 1 then
		vim.notify("File not readable: " .. filepath, vim.log.levels.WARN)
		return false
	end

	local filename = filepath:match("([^/\\]+)$") or "untitled"

	-- Try to read file content
	local ok, content = pcall(vim.fn.readfile, filepath)
	if not ok or not content then
		vim.notify("Failed to read file: " .. filepath, vim.log.levels.WARN)
		return false
	end

	-- Check if file is already in context
	for _, existing_file in ipairs(M.context_files) do
		if existing_file.path == filepath then
			vim.notify("File already in context: " .. filename, vim.log.levels.INFO)
			return true
		end
	end

	-- Add to context
	table.insert(M.context_files, {
		name = filename,
		path = filepath,
		content = table.concat(content, "\n"),
		added_at = os.time(),
	})

	-- Update database if available
	if M.db and M.db.add_context_file and M.current_session then
		local ok, err = pcall(M.db.add_context_file, M.current_session, {
			name = filename,
			path = filepath,
			added_at = os.time(),
		})
		if not ok then
			vim.notify("Failed to save context to database: " .. tostring(err), vim.log.levels.WARN)
		end
	end

	vim.notify("Added to context: " .. filename, vim.log.levels.INFO)
	return true
end

-- Clear context with error handling
function M.clear_context()
	local file_count = #M.context_files
	M.context_files = {}

	-- Update database if available
	if M.db and M.db.update_context_files and M.current_session then
		local ok, err = pcall(M.db.update_context_files, M.current_session, {})
		if not ok then
			vim.notify("Failed to clear context in database: " .. tostring(err), vim.log.levels.WARN)
		end
	end

	if file_count > 0 then
		vim.notify("Cleared " .. file_count .. " context files", vim.log.levels.INFO)
	end
end

-- Set model with validation
function M.set_model(model_name)
	if not model_name or model_name == "" then
		vim.notify("Invalid model name provided", vim.log.levels.WARN)
		return false
	end

	local config = safe_require("ai-assist.core.config")
	if not config or not config.models then
		vim.notify("Config not available, cannot validate model", vim.log.levels.WARN)
		-- Allow setting anyway as fallback
		M.selected_model = model_name
		return true
	end

	if not config.models[model_name] then
		vim.notify("Invalid model: " .. model_name, vim.log.levels.WARN)
		return false
	end

	local old_model = M.selected_model
	M.selected_model = model_name

	-- Create new session when model changes
	if M.db and M.db.create_session then
		local ok, session = pcall(M.db.create_session, model_name)
		if ok then
			M.current_session = session
		else
			vim.notify("Failed to create new session: " .. tostring(session), vim.log.levels.WARN)
			M.current_session = M.generate_session_id()
		end
	else
		M.current_session = M.generate_session_id()
	end

	-- Clear context when switching models
	M.context_files = {}

	vim.notify("Switched from " .. (old_model or "unknown") .. " to " .. model_name, vim.log.levels.INFO)
	return true
end

-- Get context string for AI queries
function M.get_context_string()
	if #M.context_files == 0 then
		return nil
	end

	local context = { "Current context files:" }
	for _, file in ipairs(M.context_files) do
		table.insert(context, string.format("\nFile: %s\n%s", file.name, file.content))
	end

	return table.concat(context, "\n")
end

-- Get conversation history
function M.get_history(limit)
	if not M.current_session then
		return {}
	end

	if not M.db or not M.db.get_history then
		return {}
	end

	local ok, history = pcall(M.db.get_history, M.current_session, limit or 20)
	if not ok then
		vim.notify("Failed to get history: " .. tostring(history), vim.log.levels.WARN)
		return {}
	end

	return history or {}
end

-- Add message to history
function M.add_message(message)
	if not M.current_session or not message then
		return false
	end

	if M.db and M.db.add_message then
		local ok, err = pcall(M.db.add_message, M.current_session, message)
		if not ok then
			vim.notify("Failed to add message to history: " .. tostring(err), vim.log.levels.WARN)
		end
		return ok
	end

	return false
end

-- Get current state info
function M.get_state_info()
	return {
		session = M.current_session,
		model = M.selected_model,
		context_files_count = #M.context_files,
		loading = M.loading,
		db_available = M.db ~= nil and type(M.db) == "table",
	}
end

-- Health check function
function M.health_check()
	local status = {
		state_module = "OK",
		database = M.db and "OK" or "FALLBACK",
		session = M.current_session and "OK" or "NONE",
		model = M.selected_model and "OK" or "NONE",
		context_files = tostring(#M.context_files),
	}

	local message = string.format(
		"AI Assistant Health Check:\n"
			.. "- State Module: %s\n"
			.. "- Database: %s\n"
			.. "- Session: %s\n"
			.. "- Model: %s (%s)\n"
			.. "- Context Files: %s",
		status.state_module,
		status.database,
		status.session,
		status.model,
		M.selected_model or "none",
		status.context_files
	)

	vim.notify(message, vim.log.levels.INFO)
	return status
end

return M
