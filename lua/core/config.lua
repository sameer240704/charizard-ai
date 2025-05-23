local M = {
	default_model = "gemini",

	models = {
		codellama = {
			name = "CodeLlama 7B",
			type = "ollama",
			model = "codellama:7b",
			url = "http://localhost:11434/api/generate",
			icon = " ",
			parameters = {
				temperature = 0.5,
				num_predict = 2048,
			},
			system_message = [[
You are an expert programming assistant specialized in writing clean, efficient code.
Follow these rules:
1. Provide complete code solutions
2. Include brief explanations when helpful
3. Use modern best practices
4. Format code properly with correct indentation]],
			template = [[
[INST] <<SYS>>
{{ .System }}
<</SYS>>

{{ .Prompt }} [/INST]],
		},
		gemini = {
			name = "Gemini 2.0 Flash",
			type = "remote",
			api_key = "AIzaSyBnFjVzLMGRc-XS18LLIaeQrxHV_8_EBSQ",
			api_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
			icon = "󰊭 ",
			parameters = {
				temperature = 0.7,
				top_p = 0.95,
				top_k = 64,
				max_output_tokens = 4096,
			},
			system_message = [[
You are a helpful AI assistant that excels at general knowledge, creative writing, 
and multi-language support. Follow these guidelines:
1. Provide clear, well-structured responses
2. When unsure, say so rather than guessing
3. Support markdown formatting for rich responses
4. Maintain a friendly and professional tone]],
			safety_settings = { -- Gemini-specific safety filters
				{
					category = "HARM_CATEGORY_DANGEROUS_CONTENT",
					threshold = "BLOCK_ONLY_HIGH",
				},
				{
					category = "HARM_CATEGORY_HARASSMENT",
					threshold = "BLOCK_ONLY_HIGH",
				},
			},
		},
	},

	ui = {
		width = 0.3,
		position = "right",
		border = "rounded",
		prompt_prefix = "🧠 ",
		response_prefix = "🤖 ",
		model_indicators = {
			gemini = "󰊭 ",
			codellama = "  ",
		},
	},
}

local function load_api_keys()
    if vim.env.GEMINI_API_KEY then
        M.models.gemini_api_key = vim.env.GEMINI_API_KEY
    end
end

load_api_keys()

return M
