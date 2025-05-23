local M = {}

local function map(mode, lhs, rhs, opts)
	local options = { noremap = true, silent = true }
	if opts then
		options = vim.tbl_extend("force", options, opts)
	end
	vim.keymap.set(mode, lhs, rhs, options)
end

function M.setup()
	local config = require("ai-assist.core.config")

	-- Default keymaps (can be overridden in config)
	local keymaps = config.keymaps
		or {
			toggle = "<leader>aa",
			ask = "<leader>ai",
			explain = "<leader>ae",
			review = "<leader>ar",
			optimize = "<leader>ao",
			add_context = "<leader>ac",
			clear_context = "<leader>aX",
			select_model = "<leader>am",
			history = "<leader>ah",
		}

	-- Main toggle
	if keymaps.toggle then
		map("n", keymaps.toggle, function()
			require("ai-assist").toggle()
		end, { desc = "Toggle AI Assistant" })
	end

	-- Quick ask (opens input window)
	if keymaps.ask then
		map("n", keymaps.ask, function()
			require("ai-assist.ui.window").create_window()
			require("ai-assist.ui.input").create_window()
		end, { desc = "Ask AI Assistant" })
	end

	-- Code explanation
	if keymaps.explain then
		map("v", keymaps.explain, function()
			require("ai-assist").explain_code()
		end, { desc = "Explain selected code" })

		map("n", keymaps.explain, function()
			require("ai-assist").query_buffer("Please explain this code:\n\n%s")
		end, { desc = "Explain current buffer" })
	end

	-- Code review
	if keymaps.review then
		map("v", keymaps.review, function()
			require("ai-assist").review_code()
		end, { desc = "Review selected code" })

		map("n", keymaps.review, function()
			require("ai-assist").query_buffer("Please review this code and suggest improvements:\n\n%s")
		end, { desc = "Review current buffer" })
	end

	-- Code optimization
	if keymaps.optimize then
		map("v", keymaps.optimize, function()
			require("ai-assist").optimize_code()
		end, { desc = "Optimize selected code" })

		map("n", keymaps.optimize, function()
			require("ai-assist").query_buffer("Please optimize this code for better performance and readability:\n\n%s")
		end, { desc = "Optimize current buffer" })
	end

	-- Context management
	if keymaps.add_context then
		map("n", keymaps.add_context, function()
			require("ai-assist").add_current_buffer()
			vim.notify("Added current buffer to context", vim.log.levels.INFO)
		end, { desc = "Add current buffer to AI context" })
	end

	if keymaps.clear_context then
		map("n", keymaps.clear_context, function()
			require("ai-assist").state.clear_context()
			vim.notify("Context cleared", vim.log.levels.INFO)
		end, { desc = "Clear AI context" })
	end

	-- Model selection
	if keymaps.select_model then
		map("n", keymaps.select_model, function()
			require("ai-assist.models.factory").select_model(function(model)
				require("ai-assist").state.set_model(model)
				vim.notify("Switched to model: " .. model, vim.log.levels.INFO)
			end)
		end, { desc = "Select AI model" })
	end

	-- Show history
	if keymaps.history then
		map("n", keymaps.history, function()
			vim.cmd("AIHistory")
		end, { desc = "Show AI conversation history" })
	end

	-- Additional useful keymaps

	-- Quick prompts
	map("v", "<leader>af", function()
		require("ai-assist").query_selection("Please fix any issues in this code:\n\n%s")
	end, { desc = "Fix selected code" })

	map("v", "<leader>ad", function()
		require("ai-assist").query_selection("Please add documentation/comments to this code:\n\n%s")
	end, { desc = "Document selected code" })

	map("v", "<leader>at", function()
		require("ai-assist").query_selection("Please write unit tests for this code:\n\n%s")
	end, { desc = "Generate tests for selected code" })

	map("v", "<leader>aR", function()
		require("ai-assist").query_selection("Please refactor this code to make it more maintainable:\n\n%s")
	end, { desc = "Refactor selected code" })

	-- Buffer-wide operations
	map("n", "<leader>aD", function()
		require("ai-assist").query_buffer("Please generate comprehensive documentation for this code:\n\n%s")
	end, { desc = "Document current buffer" })

	map("n", "<leader>aT", function()
		require("ai-assist").query_buffer("Please write comprehensive unit tests for this code:\n\n%s")
	end, { desc = "Generate tests for current buffer" })

	-- Interactive prompts
	map("n", "<leader>ap", function()
		vim.ui.input({ prompt = "Custom AI prompt: " }, function(input)
			if input and input ~= "" then
				require("ai-assist").process_query(input)
			end
		end)
	end, { desc = "Custom AI prompt" })

	map("v", "<leader>ap", function()
		vim.ui.input({ prompt = "Prompt for selected code: " }, function(input)
			if input and input ~= "" then
				require("ai-assist").query_selection(input .. "\n\n%s")
			end
		end)
	end, { desc = "Custom prompt for selection" })

	-- Window management (when AI window is focused)
	local function setup_window_keymaps(buf)
		local opts = { noremap = true, silent = true, buffer = buf }

		-- Close window
		map("n", "q", function()
			require("ai-assist.ui.window").close()
		end, opts)

		map("n", "<Esc>", function()
			require("ai-assist.ui.window").close()
		end, opts)

		-- Copy response
		map("n", "yy", function()
			local line = vim.api.nvim_get_current_line()
			vim.fn.setreg("+", line)
			vim.notify("Line copied to clipboard", vim.log.levels.INFO)
		end, opts)

		-- Clear window
		map("n", "C", function()
			require("ai-assist.ui.window").clear()
		end, opts)

		-- Refresh/toggle input
		map("n", "i", function()
			require("ai-assist.ui.input").create_window()
		end, opts)

		-- Show help
		map("n", "?", function()
			local help_lines = {
				"=== AI Assistant Help ===",
				"",
				"q, <Esc>  - Close window",
				"i         - Open input window",
				"C         - Clear window",
				"yy        - Copy current line",
				"?         - Show this help",
				"",
				"Available commands:",
				":AIAsk <prompt>     - Ask a question",
				":AIModel <model>    - Switch model",
				":AIAddContext <file> - Add context",
				":AIHistory          - Show history",
				":AIHealth           - Check status",
				"",
				"See :help ai-assist for more information",
			}

			require("ai-assist.ui.window").clear()
			require("ai-assist.ui.window").append_lines(help_lines)
		end, opts)
	end

	-- Auto-setup window keymaps when AI window is created
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "ai_assist",
		callback = function(event)
			setup_window_keymaps(event.buf)
		end,
	})

	-- Input window keymaps
	local function setup_input_keymaps(buf)
		local opts = { noremap = true, silent = true, buffer = buf }

		-- Submit on Ctrl+Enter (keeping Enter for newlines)
		map("i", "<C-CR>", function()
			require("ai-assist.ui.input").submit()
		end, opts)

		-- Close on Escape
		map("i", "<C-c>", function()
			require("ai-assist.ui.window").close()
		end, opts)

		-- History navigation (simple implementation)
		map("i", "<C-p>", function()
			-- TODO: Implement history navigation
			vim.notify("History navigation not yet implemented", vim.log.levels.INFO)
		end, opts)
	end

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "ai_assist_input",
		callback = function(event)
			setup_input_keymaps(event.buf)
		end,
	})
end

-- Function to disable all keymaps (useful for troubleshooting)
function M.disable()
	-- This would remove all AI-assist keymaps
	-- Implementation depends on how we want to track them
	vim.notify("Keymap disabling not implemented yet", vim.log.levels.WARN)
end

-- Function to list all active keymaps
function M.list()
	local config = require("ai-assist.core.config")
	local keymaps = config.keymaps or {}

	local active = {}
	for action, keymap in pairs(keymaps) do
		if keymap then
			table.insert(active, string.format("%-15s: %s", action, keymap))
		end
	end

	if #active > 0 then
		vim.notify("Active AI Assistant keymaps:\n" .. table.concat(active, "\n"), vim.log.levels.INFO)
	else
		vim.notify("No keymaps configured", vim.log.levels.INFO)
	end
end

return M
