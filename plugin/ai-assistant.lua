return {
	{
		"ai-assist",
		dir = vim.fn.stdpath("config") .. "/lua/ai-assist",
		dependencies = { "ellisonleao/dotenv.nvim" },
		config = function()
			-- Load and configure the AI assistant
			require("ai-assist").setup({
				-- Your configuration options
				default_model = "gemini", -- or "deepseek" or "gemma"

				-- Configure your API keys here
				models = {
					gemini = {
						api_key = os.getenv("GEMINI_API_KEY"), -- Set this in your environment or replace with actual key
					},
					-- Local models don't need API keys, but you can customize other settings
					deepseek = {
						-- Any custom Deepseek settings
					},
					gemma = {
						-- Any custom Gemma settings
					},
				},

				-- UI customization
				ui = {
					width = 0.3, -- Width of sidebar (30% of screen)
					border = "rounded",
				},
			})
			-- Key mappings
			vim.keymap.set("n", "<leader>ai", "<Cmd>AIAssistToggle<CR>", { desc = "Toggle AI Assistant" })
			vim.keymap.set("n", "<leader>aq", "<Cmd>AIAssistQuery<CR>", { desc = "AI Assistant Query" })
			vim.keymap.set("v", "<leader>ae", "<Cmd>AIAssistExplain<CR>", { desc = "Explain Code" })
			vim.keymap.set("v", "<leader>ap", "<Cmd>AIAssistImprove<CR>", { desc = "Improve Code" })
			vim.keymap.set("n", "<leader>am", "<Cmd>AIAssistSelectModel<CR>", { desc = "Select AI Model" })
			vim.keymap.set("n", "<leader>ah", "<Cmd>AIAssistHealthCheck<CR>", { desc = "AI Health Check" })

			-- Add these new keymaps for better control
			vim.keymap.set(
				"n",
				"<leader>as",
				'<Cmd>lua require("ai-assist").submit_query()<CR>',
				{ desc = "Submit AI Query" }
			)
			vim.keymap.set("n", "<leader>ac", "<Cmd>AIAssistClearContext<CR>", { desc = "Clear AI Context" })
		end,
	},
}
