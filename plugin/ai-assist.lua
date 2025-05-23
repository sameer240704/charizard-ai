return {
	{
		"ai-assist",
		dir = vim.fn.stdpath("config") .. "/lua/ai-assist",
		dependencies = { "ellisonleao/dotenv.nvim" },
		event = "VeryLazy", -- Load plugin lazily for better startup performance
		config = function()
			-- Ensure dotenv is loaded first
			local ok_dotenv, dotenv = pcall(require, "dotenv")
			if ok_dotenv then
				dotenv.setup()
			end

			-- Check if ai-assist module exists
			local ok_ai, ai_assist = pcall(require, "ai-assist")
			if not ok_ai then
				vim.notify("AI Assistant plugin not found", vim.log.levels.ERROR)
				return
			end

			-- Setup AI assistant with comprehensive configuration
			ai_assist.setup({
				-- Default model selection
				default_model = "gemini", -- Options: "gemini", "deepseek", "gemma"

				-- Model configurations
				models = {
					gemini = {
						api_key = os.getenv("GEMINI_API_KEY"),
						model_name = "gemini-pro",
						temperature = 0.7,
						max_tokens = 2048,
						timeout = 30000, -- 30 seconds
					},
					deepseek = {
						api_key = os.getenv("DEEPSEEK_API_KEY"),
						model_name = "deepseek-coder",
						temperature = 0.3,
						max_tokens = 4096,
						timeout = 30000,
					},
					gemma = {
						-- Local model configuration
						model_path = os.getenv("GEMMA_MODEL_PATH") or "~/models/gemma",
						temperature = 0.5,
						max_tokens = 2048,
						context_length = 8192,
					},
				},

				-- UI customization
				ui = {
					width = 0.3, -- 30% of screen width
					height = 0.8, -- 80% of screen height
					border = "rounded", -- Options: "single", "double", "rounded", "solid", "shadow"
					position = "right", -- Options: "left", "right", "top", "bottom"
					winblend = 10, -- Transparency (0-100)
					title = " AI Assistant ",
					title_pos = "center",
				},

				-- Chat behavior
				chat = {
					auto_scroll = true,
					save_history = true,
					history_file = vim.fn.stdpath("data") .. "/ai-assist-history.json",
					max_history_entries = 100,
					context_lines = 10, -- Lines of code context to include
				},

				-- Code analysis settings
				code_analysis = {
					include_file_type = true,
					include_line_numbers = true,
					max_code_length = 5000, -- Maximum characters to send
				},

				-- Auto-completion settings
				completion = {
					enabled = false, -- Set to true if you want AI-powered completion
					trigger_length = 3,
					max_suggestions = 5,
				},
			})

			-- Create user commands
			vim.api.nvim_create_user_command("AIAssistToggle", function()
				ai_assist.toggle()
			end, { desc = "Toggle AI Assistant sidebar" })

			vim.api.nvim_create_user_command("AIAssistQuery", function(opts)
				if opts.args and opts.args ~= "" then
					ai_assist.query(opts.args)
				else
					ai_assist.open_query_input()
				end
			end, {
				nargs = "?",
				desc = "Send query to AI Assistant",
			})

			vim.api.nvim_create_user_command("AIAssistExplain", function()
				ai_assist.explain_selection()
			end, {
				range = true,
				desc = "Explain selected code",
			})

			vim.api.nvim_create_user_command("AIAssistImprove", function()
				ai_assist.improve_code()
			end, {
				range = true,
				desc = "Get suggestions to improve code",
			})

			vim.api.nvim_create_user_command("AIAssistSelectModel", function()
				ai_assist.select_model()
			end, { desc = "Select AI model" })

			vim.api.nvim_create_user_command("AIAssistHealthCheck", function()
				ai_assist.health_check()
			end, { desc = "Check AI Assistant health" })

			vim.api.nvim_create_user_command("AIAssistClearContext", function()
				ai_assist.clear_context()
			end, { desc = "Clear conversation context" })

			vim.api.nvim_create_user_command("AIAssistRestart", function()
				ai_assist.restart()
			end, { desc = "Restart AI Assistant" })

			-- Key mappings with better descriptions and error handling
			local function safe_keymap(mode, lhs, rhs, opts)
				local success, err = pcall(vim.keymap.set, mode, lhs, rhs, opts)
				if not success then
					vim.notify("Failed to set keymap " .. lhs .. ": " .. err, vim.log.levels.WARN)
				end
			end

			-- Main AI Assistant keymaps
			safe_keymap("n", "<leader>ai", "<cmd>AIAssistToggle<cr>", {
				desc = "Toggle AI Assistant",
				silent = true,
			})

			safe_keymap("n", "<leader>aq", "<cmd>AIAssistQuery<cr>", {
				desc = "AI Assistant Query",
				silent = true,
			})

			safe_keymap("v", "<leader>ae", "<cmd>AIAssistExplain<cr>", {
				desc = "Explain selected code",
				silent = true,
			})

			safe_keymap("v", "<leader>ap", "<cmd>AIAssistImprove<cr>", {
				desc = "Improve selected code",
				silent = true,
			})

			safe_keymap("n", "<leader>am", function()
				require("ai-assist.models.factory").select_model(function(model)
					require("ai-assist").state.set_model(model)
					vim.notify("Switched to model: " .. model, vim.log.levels.INFO)
				end)
			end, {
				desc = "Select AI Model",
				silent = true,
			})

			safe_keymap("n", "<leader>ah", "<cmd>AIAssistHealthCheck<cr>", {
				desc = "AI Health Check",
				silent = true,
			})

			safe_keymap("n", "<leader>ac", "<cmd>AIAssistClearContext<cr>", {
				desc = "Clear AI Context",
				silent = true,
			})

			safe_keymap("n", "<leader>ar", "<cmd>AIAssistRestart<cr>", {
				desc = "Restart AI Assistant",
				silent = true,
			})

			-- Quick query keymap
			safe_keymap("n", "<leader>as", function()
				local query = vim.fn.input("AI Query: ")
				if query and query ~= "" then
					ai_assist.query(query)
				end
			end, {
				desc = "Submit quick AI query",
				silent = true,
			})

			-- Context-aware keymaps (only in certain file types)
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "lua", "python", "javascript", "typescript", "rust", "go", "java", "c", "cpp" },
				callback = function()
					-- Code-specific keymaps
					safe_keymap("n", "<leader>ad", function()
						ai_assist.generate_docs()
					end, {
						desc = "Generate documentation",
						buffer = true,
						silent = true,
					})

					safe_keymap("n", "<leader>at", function()
						ai_assist.generate_tests()
					end, {
						desc = "Generate tests",
						buffer = true,
						silent = true,
					})

					safe_keymap("n", "<leader>af", function()
						ai_assist.fix_code()
					end, {
						desc = "Fix code issues",
						buffer = true,
						silent = true,
					})
				end,
			})

			-- Auto-save chat history on exit
			vim.api.nvim_create_autocmd("VimLeavePre", {
				callback = function()
					if ai_assist.is_active() then
						ai_assist.save_history()
					end
				end,
			})

			-- Notify successful setup
			vim.notify("AI Assistant loaded successfully", vim.log.levels.INFO)
		end,
	},
}
