local api = vim.api
local fn = vim.fn
local cmd = vim.cmd

-- Plugin configuration
local config = {
	-- Default model to use
	default_model = "gemini",

	-- Available models configuration
	models = {
		gemini = {
			name = "Gemini 2.0",
			type = "remote",
			api_key = "AIzaSyBnFjVzLMGRc-XS18LLIaeQrxHV_8_EBSQ",
			api_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
			icon = "󰊭", -- Pretty icon for Gemini
		},
		deepseek = {
			name = "Deepseek R1",
			type = "ollama",
			model = "deepseek-coder",
			url = "http://localhost:11434/api/generate",
			icon = "󰚩", -- Custom icon for Deepseek
		},
		gemma = {
			name = "Gemma 3",
			type = "ollama",
			model = "gemma3:4b", -- Must match EXACTLY what 'ollama list' shows
			url = "http://localhost:11434/api/generate",
			system_message = "You are a helpful coding assistant. Provide concise, helpful responses.",
			icon = "󰊥", -- Custom icon for Gemma
			parameters = {
				temperature = 0.7,
				top_p = 0.95, -- Matches the Modelfile
				top_k = 64, -- Matches the Modelfile
				stop = "<end_of_turn>", -- Important for proper response formatting
			},
			template = [[<start_of_turn>user
{{ .Prompt }}<end_of_turn>
<start_of_turn>model
]], -- Matches according to my modelfile structure
		},
	},

	-- UI settings with improved design
	ui = {
		width = 0.3, -- Slightly wider for better readability
		position = "right",
		border = "rounded",
		prompt_prefix = "🧠 ",
		response_prefix = "🤖 ",
		icons = {
			header = "󰚩 ",
			context = "📎 ",
			model = "🧠 ",
			loading = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }, -- Spinner animation
			success = "✓ ",
			error = "✗ ",
		},
		colors = {
			header = "Special",
			border = "FloatBorder",
			title = "Title",
			prompt = "Function",
			response = "Identifier",
			code_block = "Type",
			separator = "Comment",
			context = "Special",
			error = "ErrorMsg",
			success = "SuccessMsg",
		},
		theme = "dark", -- Options: "default", "dark", "light", "minimal"
		animation = true, -- Enable/disable animations
		auto_scroll = true, -- Auto-scroll to new content
	},

	-- System messages for different contexts
	system_messages = {
		default = "You are a helpful coding assistant. Provide concise, helpful responses.",
		code_explanation = "Explain the following code clearly and concisely:",
		code_generation = "Generate code based on the following requirements:",
		file_context = "Consider the following file content for context:",
	},

	-- Keyboard shortcuts
	keymaps = {
		toggle = "<leader>ai",
		query = "<leader>aq",
		explain = "<leader>ae",
		improve = "<leader>ai",
		model = "<leader>am",
		context = "<leader>ac",
		clear = "<leader>ax",
	},
}

-- Buffer and window variables
local state = {
	buf = nil,
	win = nil,
	input_buf = nil,
	input_win = nil,
	history = {},
	selected_model = config.default_model,
	active = false,
	context_files = {},
	loading = false,
	spinner_idx = 1,
	spinner_timer = nil,
	theme_colors = {},
}

-- Utility functions
local utils = {}

-- Theming utilities
function utils.load_theme()
	local theme = config.ui.theme
	local colors = {}

	if theme == "dark" then
		colors = {
			bg = "#282c34",
			fg = "#abb2c0",
			border = "#3e4452",
			header_bg = "#21252b",
			header_fg = "#61afef",
			prompt_bg = "#2c313c",
			prompt_fg = "#56b6c2",
			response_bg = "#2c313c",
			response_fg = "#98c379",
			code_bg = "#1e222a",
			code_fg = "#d19a66",
		}
	elseif theme == "light" then
		colors = {
			bg = "#e1e2e7",
			fg = "#3760bf",
			border = "#a8aecb",
			header_bg = "#d5d6db",
			header_fg = "#2e7de9",
			prompt_bg = "#e9e9ec",
			prompt_fg = "#587539",
			response_bg = "#e9e9ec",
			response_fg = "#b15c00",
			code_bg = "#e1e2e7",
			code_fg = "#8c6c3e",
		}
	elseif theme == "minimal" then
		colors = {
			bg = "NONE",
			fg = "NONE",
			border = "NONE",
			header_bg = "NONE",
			header_fg = "NONE",
			prompt_bg = "NONE",
			prompt_fg = "NONE",
			response_bg = "NONE",
			response_fg = "NONE",
			code_bg = "NONE",
			code_fg = "NONE",
		}
	else -- default
		colors = {
			-- Use Vim's highlight groups
			bg = "Normal",
			fg = "Normal",
			border = "FloatBorder",
			header_bg = "TabLineFill",
			header_fg = "Title",
			prompt_bg = "Normal",
			prompt_fg = "Function",
			response_bg = "Normal",
			response_fg = "Identifier",
			code_bg = "Normal",
			code_fg = "Type",
		}
	end

	state.theme_colors = colors
	return colors
end

-- Apply theme to window
function utils.apply_theme(win, buf)
	local colors = state.theme_colors

	if vim.tbl_isempty(colors) then
		colors = utils.load_theme()
	end

	if type(colors.bg) == "string" and colors.bg:match("^#") then
		-- Use hex color directly
		api.nvim_set_option_value("winhighlight", "Normal:AIAssistBg,FloatBorder:AIAssistBorder", { win = win })
		vim.cmd(string.format("highlight AIAssistBg guibg=%s guifg=%s", colors.bg, colors.fg))
		vim.cmd(string.format("highlight AIAssistBorder guifg=%s", colors.border))
	else
		-- Use highlight group
		api.nvim_set_option_value(
			"winhighlight",
			"Normal:" .. colors.bg .. ",FloatBorder:" .. colors.border,
			{ win = win }
		)
	end
end

-- Create a floating window with improved styling
function utils.create_floating_win(buf, opts)
	local width = math.floor(vim.o.columns * opts.width)
	local height = vim.o.lines - 4
	local col = opts.position == "right" and (vim.o.columns - width) or 0

	local win = api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = 1,
		style = "minimal",
		border = opts.border,
		title = " AI Assistant ",
		title_pos = "center",
	})

	api.nvim_set_option_value("wrap", true, { win = win })
	api.nvim_set_option_value("linebreak", true, { win = win })
	api.nvim_set_option_value("conceallevel", 2, { win = win })
	api.nvim_set_option_value("concealcursor", "nvc", { win = win })

	-- Apply theme
	utils.apply_theme(win, buf)

	return win
end

-- HTTP request function using curl
function utils.http_request(url, method, headers, body)
	local cmd = string.format("curl -s -X %s", method)

	-- Add headers
	for k, v in pairs(headers) do
		cmd = cmd .. string.format(" -H '%s: %s'", k, v)
	end

	-- Add body if present
	if body and (method == "POST" or method == "PUT") then
		cmd = cmd .. string.format(" -d %s", vim.fn.shellescape(body))
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

	-- Try to parse JSON only if the response looks like JSON
	if response and response:sub(1, 1) == "{" then
		local success, json = pcall(vim.json.decode, response)
		if success then
			return json
		else
			return nil, "Failed to parse JSON: " .. json
		end
	end

	return nil, "Unexpected response: " .. response
end

-- Get text from current buffer
function utils.get_current_buffer_content()
	local lines = api.nvim_buf_get_lines(0, 0, -1, false)
	return table.concat(lines, "\n")
end

-- Escape string for json
function utils.json_escape(str)
	local s = str:gsub([[\]], [[\\]])
	s = s:gsub('"', '\\"')
	s = s:gsub("\n", "\\n")
	s = s:gsub("\r", "\\r")
	s = s:gsub("\t", "\\t")
	return s
end

-- Get selected text
function utils.get_visual_selection()
	local start_pos = fn.getpos("'<")
	local end_pos = fn.getpos("'>")
	local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

	if #lines == 0 then
		return ""
	end

	-- Adjust for partial first/last line selection
	if #lines == 1 then
		lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
	else
		lines[1] = string.sub(lines[1], start_pos[3])
		lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
	end

	return table.concat(lines, "\n")
end

-- Check if Ollama is running
function utils.check_ollama_running()
	-- Try multiple ways to check if Ollama is running
	local methods = {
		function()
			local handle = io.popen("curl -s -o /dev/null -w '%{http_code}' http://localhost:11434/")
			local result = handle:read("*a")
			handle:close()
			return result == "200"
		end,
		function()
			local handle = io.popen("pgrep -f 'ollama serve' 2>/dev/null")
			local result = handle:read("*a")
			handle:close()
			return result ~= ""
		end,
		function()
			local handle = io.popen("ss -tulnp | grep ':11434' 2>/dev/null")
			local result = handle:read("*a")
			handle:close()
			return result ~= ""
		end,
	}

	for _, method in ipairs(methods) do
		local success, result = pcall(method)
		if success and result then
			return true
		end
	end

	return false
end

-- Generate a pretty header with model icon and details
function utils.generate_header()
	local model = config.models[state.selected_model]
	local model_icon = model.icon or config.ui.icons.model
	local header_icon = config.ui.icons.header
	local header_width = math.floor(vim.o.columns * config.ui.width) - 4

	local left_border = "┌" .. string.rep("─", header_width) .. "┐"
	local right_border = "└" .. string.rep("─", header_width) .. "┘"

	local header = {
		left_border,
		"│"
			.. string.rep(" ", math.floor((header_width - 18) / 2))
			.. header_icon
			.. "AI CODE ASSISTANT"
			.. string.rep(" ", math.ceil((header_width - 18) / 2))
			.. "│",
		"│" .. string.rep(" ", header_width) .. "│",
		"│ " .. model_icon .. " Model: " .. model.name .. string.rep(" ", header_width - #model.name - 10) .. "│",
	}

	-- Add command info
	table.insert(header, "│" .. string.rep(" ", header_width) .. "│")
	table.insert(header, "│ ⌨  Commands:" .. string.rep(" ", header_width - 12) .. "│")
	table.insert(
		header,
		"│   • "
			.. config.keymaps.model
			.. " - Change Model"
			.. string.rep(" ", header_width - 21 - #config.keymaps.model)
			.. "│"
	)
	table.insert(
		header,
		"│   • "
			.. config.keymaps.context
			.. " - Add Context"
			.. string.rep(" ", header_width - 22 - #config.keymaps.context)
			.. "│"
	)
	table.insert(
		header,
		"│   • "
			.. config.keymaps.query
			.. " - Ask Question"
			.. string.rep(" ", header_width - 23 - #config.keymaps.query)
			.. "│"
	)
	table.insert(header, "│" .. string.rep(" ", header_width) .. "│")
	table.insert(header, right_border)
	table.insert(header, "")

	return header
end

-- Main plugin object
local ai_assist = {}

-- Initialize the assistant
function ai_assist.setup(user_config)
	-- Merge user config with defaults
	if user_config then
		for k, v in pairs(user_config) do
			if type(v) == "table" and type(config[k]) == "table" then
				config[k] = vim.tbl_deep_extend("force", config[k], v)
			else
				config[k] = v
			end
		end
	end

	-- Load theme
	utils.load_theme()

	-- Setup highlights
	ai_assist.setup_syntax_highlighting()

	-- Create commands
	cmd([[command! AIAssistToggle lua require('ai-assist').toggle()]])
	cmd([[command! AIAssistQuery lua require('ai-assist').query()]])
	cmd([[command! AIAssistSelectModel lua require('ai-assist').select_model()]])
	cmd([[command! AIAssistAddContext lua require('ai-assist').add_context()]])
	cmd([[command! AIAssistClearContext lua require('ai-assist').clear_context()]])
	cmd([[command! -range AIAssistExplain lua require('ai-assist').explain_selection()]])
	cmd([[command! -range AIAssistImprove lua require('ai-assist').improve_selection()]])
	cmd([[command! AIAssistHealthCheck lua require('ai-assist').health_check()]])

	-- Set up global keymaps
	if config.keymaps.toggle then
		vim.api.nvim_set_keymap("n", config.keymaps.toggle, ":AIAssistToggle<CR>", { noremap = true, silent = true })
	end
	if config.keymaps.query then
		vim.api.nvim_set_keymap("n", config.keymaps.query, ":AIAssistQuery<CR>", { noremap = true, silent = true })
	end
	if config.keymaps.explain then
		vim.api.nvim_set_keymap("v", config.keymaps.explain, ":AIAssistExplain<CR>", { noremap = true, silent = true })
	end
	if config.keymaps.improve then
		vim.api.nvim_set_keymap("v", config.keymaps.improve, ":AIAssistImprove<CR>", { noremap = true, silent = true })
	end
	if config.keymaps.model then
		vim.api.nvim_set_keymap(
			"n",
			config.keymaps.model,
			":AIAssistSelectModel<CR>",
			{ noremap = true, silent = true }
		)
	end
	if config.keymaps.context then
		vim.api.nvim_set_keymap(
			"n",
			config.keymaps.context,
			":AIAssistAddContext<CR>",
			{ noremap = true, silent = true }
		)
	end
	if config.keymaps.clear then
		vim.api.nvim_set_keymap(
			"n",
			config.keymaps.clear,
			":AIAssistClearContext<CR>",
			{ noremap = true, silent = true }
		)
	end
end

-- Toggle the assistant window
function ai_assist.toggle()
	if state.active then
		ai_assist.close()
	else
		ai_assist.open()
	end
end

-- Create animated spinner for loading indicator
function ai_assist.start_spinner()
	if state.spinner_timer then
		return
	end

	state.spinner_idx = 1

	-- Use vim.fn.timer_start instead of vim.loop.new_timer
	state.spinner_timer = vim.fn.timer_start(100, function()
		vim.schedule(function()
			if not state.loading or not state.buf or not api.nvim_buf_is_valid(state.buf) then
				ai_assist.stop_spinner()
				return
			end

			-- Update spinner on loading line
			local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
			for i = #lines, 1, -1 do
				if lines[i]:match("Loading%.%.%.") then
					local spinner_char = config.ui.icons.loading[state.spinner_idx]
					lines[i] = config.ui.response_prefix .." " .. spinner_char .. " Loading..."
					api.nvim_buf_set_lines(state.buf, i-1, i, false, {lines[i]})
					break
				end
			end

			-- Increment spinner index
			state.spinner_idx = (state.spinner_idx % #config.ui.icons.loading) + 1
		end)
	end, { ["repeat"] = -1 }) -- -1 means repeat indefinitely
end

-- Stop spinner animation
function ai_assist.stop_spinner()
    if state.spinner_timer then
        vim.fn.timer_stop(state.spinner_timer)
        state.spinner_timer = nil
    end
end

-- Open the assistant
function ai_assist.open()
	if state.active then
		return
	end

	-- Create main buffer if needed
	if not state.buf or not api.nvim_buf_is_valid(state.buf) then
		state.buf = api.nvim_create_buf(false, true)
		api.nvim_set_option_value("buftype", "nofile", { buf = state.buf })
		api.nvim_set_option_value("swapfile", false, { buf = state.buf })
		api.nvim_set_option_value("filetype", "ai-assist", { buf = state.buf })
		api.nvim_buf_set_name(state.buf, "AI Assistant")

		-- Initialize with header
		local header = utils.generate_header()

		-- Add context files info if any
		if #state.context_files > 0 then
			table.insert(header, config.ui.icons.context .. "Context files: ")
			for i, file_info in ipairs(state.context_files) do
				local file_line = "  • " .. file_info.name
				table.insert(header, file_line)
			end
			table.insert(header, "")
		end

		-- Add prompt message
		table.insert(header, "Type your query below:")
		table.insert(header, "")

		-- Add history if exists
		if #state.history > 0 then
			for _, entry in ipairs(state.history) do
				table.insert(header, config.ui.prompt_prefix .. entry.query)
				table.insert(header, "")

				-- Format the response for history replay
				local response_lines = ai_assist.format_response(entry.response)
				for _, line in ipairs(response_lines) do
					table.insert(header, line)
				end
			end
		end

		api.nvim_buf_set_lines(state.buf, 0, -1, false, header)
	end

	-- Create main window
	state.win = utils.create_floating_win(state.buf, config.ui)

	-- Create input buffer and window
	ai_assist.create_input_window()

	state.active = true
end

-- Create input window
function ai_assist.create_input_window()
	state.input_buf = api.nvim_create_buf(false, true)

	-- Set proper buffer options
	api.nvim_set_option_value("buftype", "prompt", { buf = state.input_buf })
	api.nvim_set_option_value("bufhidden", "hide", { buf = state.input_buf })
	api.nvim_set_option_value("swapfile", false, { buf = state.input_buf })

	-- Setup prompt callback
	vim.fn.prompt_setcallback(state.input_buf, function(text)
		require("ai-assist").process_query(text)
	end)
	vim.fn.prompt_setprompt(state.input_buf, config.ui.prompt_prefix)

	-- Calculate input window position
	local main_width = math.floor(vim.o.columns * config.ui.width)
	local main_col = config.ui.position == "right" and (vim.o.columns - main_width) or 0

	-- Create input window (3 lines tall, at bottom of main window)
	state.input_win = api.nvim_open_win(state.input_buf, true, {
		relative = "editor",
		width = main_width,
		height = 3,
		col = main_col,
		row = vim.o.lines - 4,
		style = "minimal",
		border = config.ui.border,
		title = " Ask AI ",
		title_pos = "center",
	})

	-- Apply theme
	utils.apply_theme(state.input_win, state.input_buf)

	-- Set insert mode and callback for CR
	cmd("startinsert")

	-- Set up submit mapping
	api.nvim_buf_set_keymap(
		state.input_buf,
		"i",
		"<CR>",
		'<Cmd>lua require("ai-assist").submit_query()<CR>',
		{ noremap = true, silent = true }
	)
	api.nvim_buf_set_keymap(state.input_buf, "i", "<C-CR>", "<CR>", { noremap = true }) -- Alternative enter
	api.nvim_buf_set_keymap(
		state.input_buf,
		"n",
		"<CR>",
		'<Cmd>lua require("ai-assist").submit_query()<CR>',
		{ noremap = true, silent = true }
	)
	api.nvim_buf_set_keymap(
		state.input_buf,
		"n",
		"q",
		'<Cmd>lua require("ai-assist").close()<CR>',
		{ noremap = true, silent = true }
	)
	api.nvim_buf_set_keymap(
		state.input_buf,
		"n",
		"<Esc>",
		'<Cmd>lua require("ai-assist").close()<CR>',
		{ noremap = true, silent = true }
	)
end

-- Close the assistant
function ai_assist.close()
	ai_assist.stop_spinner()

	if state.win and api.nvim_win_is_valid(state.win) then
		api.nvim_win_close(state.win, true)
		state.win = nil
	end

	if state.input_win and api.nvim_win_is_valid(state.input_win) then
		api.nvim_win_close(state.input_win, true)
		state.input_win = nil
	end

	state.active = false
end

-- Submit query
function ai_assist.submit_query()
	if not state.input_buf or not api.nvim_buf_is_valid(state.input_buf) then
		return
	end

	-- Get query from input buffer
	local input_lines = api.nvim_buf_get_lines(state.input_buf, 0, -1, false)
	local query = table.concat(input_lines, "\n"):gsub(config.ui.prompt_prefix, "")

	if query == "" then
		return
	end

	-- Clear input buffer
	api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { config.ui.prompt_prefix })
	api.nvim_win_set_cursor(state.input_win, { 1, #config.ui.prompt_prefix + 1 })
	cmd("startinsert")

	-- Process query
	ai_assist.process_query(query)
end

-- Function to apply syntax highlighting
function ai_assist.setup_syntax_highlighting()
	cmd([[
        augroup AIAssistSyntax
            autocmd!
            autocmd FileType ai-assist call s:setup_ai_assist_syntax()
        augroup END
        
        function! s:setup_ai_assist_syntax()
            " Clear existing syntax
            syntax clear
            
            " Define syntax groups
            syntax match AIAssistHeader /^│.*│$/
            syntax match AIAssistBorder /[┌┐└┘─│]/
            syntax match AIAssistPrompt /^🧠.*$/
            syntax match AIAssistAI /^🤖.*$/
            syntax match AIAssistCodeBlock /^.*Code block.*:/
            syntax match AIAssistCodeSeparator /^----------------------------------------$/
            syntax match AIAssistContextFiles /^📎 Context files:.*$/
            syntax match AIAssistContextFile /^  • .*$/
            syntax match AIAssistCommand /^│   • .*$/
            syntax match AIAssistLoading /^🤖 . Loading...$/
            syntax match AIAssistError /^🤖 Error:.*$/
            
            " Set highlighting
            highlight default AIAssistHeader guifg=#7aa2f7 gui=bold
            highlight default AIAssistBorder guifg=#414868
            highlight default AIAssistPrompt guifg=#bb9af7 gui=bold
            highlight default AIAssistAI guifg=#9ece6a
            highlight default AIAssistCodeBlock guifg=#e0af68 gui=bold
            highlight default AIAssistCodeSeparator guifg=#565f89
            highlight default AIAssistContextFiles guifg=#f7768e gui=bold
            highlight default AIAssistContextFile guifg=#bb9af7
            highlight default AIAssistCommand guifg=#89ddff
            highlight default AIAssistLoading guifg=#7dcfff gui=bold
            highlight default AIAssistError guifg=#f7768e gui=bold
        endfunction
    ]])
end

-- Function to process and format AI responses
function ai_assist.format_response(response_text)
	-- Check if empty
	if not response_text or response_text == "" then
		return { "No response received" }
	end

	-- Split response into lines
	local response_lines = vim.split(response_text, "\n", { plain = true })

	-- Process code blocks
	local formatted_lines = {}
	local in_code_block = false
	local code_lang = ""
	local indent = string.rep(" ", #config.ui.response_prefix)

	for i, line in ipairs(response_lines) do
		-- Check for code block start
		local code_start = line:match("^```(%w*)$")
		if code_start then
			in_code_block = true
			code_lang = code_start

			-- Add formatted code block header
			table.insert(formatted_lines, "")
			if code_lang and code_lang ~= "" then
				table.insert(formatted_lines, "Code block (" .. code_lang .. "):")
			else
				table.insert(formatted_lines, "Code block:")
			end

			-- Add a separator line
			table.insert(formatted_lines, string.rep("─", 40))

		-- Check for code block end
		elseif line:match("^```$") and in_code_block then
			in_code_block = false
			code_lang = ""

			-- Add a separator line
			table.insert(formatted_lines, string.rep("─", 40))
			table.insert(formatted_lines, "")
		else
			-- Regular line processing
			table.insert(formatted_lines, line)
		end
	end

	-- Apply prefix to the first line and indentation to subsequent lines
	if #formatted_lines > 0 then
		formatted_lines[1] = config.ui.response_prefix .. formatted_lines[1]
		for i = 2, #formatted_lines do
			formatted_lines[i] = indent .. formatted_lines[i]
		end
	end

	-- Add blank line at the end
	table.insert(formatted_lines, "")

	return formatted_lines
end

-- Process AI query
function ai_assist.process_query(query)
	if state.loading then
		return
	end

	state.loading = true

	-- Add query to main buffer
	local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
	table.insert(lines, config.ui.prompt_prefix .. query)
	table.insert(lines, "")
	table.insert(lines, config.ui.response_prefix .. " Loading...")
	api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)

	-- Start loading animation
	ai_assist.start_spinner()

	-- Scroll to bottom
	if state.win and api.nvim_win_is_valid(state.win) then
		api.nvim_win_set_cursor(state.win, { #lines, 0 })
	end

	-- Prepare the actual query to the model
	local model_config = config.models[state.selected_model]

	-- Create context with system message and file contexts
	local context = {}
	if model_config.system_message then
		table.insert(context, model_config.system_message)
	else
		table.insert(context, config.system_messages.default)
	end

	-- Add context files if present
	if #state.context_files > 0 then
		table.insert(context, "\nContext files:")
		for _, file_info in ipairs(state.context_files) do
			table.insert(context, "\nFile: " .. file_info.name)
			table.insert(context, file_info.content)
		end
	end

	local context_str = table.concat(context, "\n")

	-- Execute in background to avoid blocking UI
	vim.schedule(function()
		-- Create a coroutine to handle the async request
		local co = coroutine.create(function()
			local response_text

			if model_config.type == "remote" then
				response_text = ai_assist.query_remote_model(model_config, context_str, query)
			elseif model_config.type == "ollama" then
				response_text = ai_assist.query_ollama_model(model_config, context_str, query)
			else
				response_text = "Error: Unknown model type: " .. model_config.type
			end

			-- Format response and update buffer
			local response_lines = ai_assist.format_response(response_text)

			-- Update buffer with response
			if state.buf and api.nvim_buf_is_valid(state.buf) then
				local current_lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)

				-- Find and replace the loading line
				for i = #current_lines, 1, -1 do
					if current_lines[i]:match("Loading%.%.%.") then
						table.remove(current_lines, i)
						break
					end
				end

				-- Add formatted response
				for _, line in ipairs(response_lines) do
					table.insert(current_lines, line)
				end

				-- Update buffer
				api.nvim_buf_set_lines(state.buf, 0, -1, false, current_lines)

				-- Scroll to bottom if auto_scroll is enabled
				if config.ui.auto_scroll and state.win and api.nvim_win_is_valid(state.win) then
					api.nvim_win_set_cursor(state.win, { #current_lines, 0 })
				end
			end

			-- Add to history
			table.insert(state.history, {
				query = query,
				response = response_text,
			})

			-- Set loading to false
			state.loading = false
			ai_assist.stop_spinner()
		end)

		-- Resume the coroutine
		coroutine.resume(co)
	end)
end

-- Query Gemini or other remote API-based models
function ai_assist.query_remote_model(model_config, context, query)
	local prompt = context .. "\n\nUser query: " .. query

	-- Check if API key is set
	if not model_config.api_key or model_config.api_key == "" then
		return "Error: API key not configured for " .. model_config.name
	end

	-- Prepare request payload
	local payload = {
		contents = {
			{
				parts = {
					{ text = prompt },
				},
			},
		},
		generationConfig = {
			temperature = model_config.temperature or 0.7,
			topP = model_config.top_p or 0.95,
			topK = model_config.top_k or 40,
			maxOutputTokens = model_config.max_tokens or 4096,
			stopSequences = model_config.stop_sequences or {},
		},
	}

	-- Convert to JSON
	local body = vim.json.encode(payload)

	-- Prepare headers
	local headers = {
		["Content-Type"] = "application/json",
		["Accept"] = "application/json",
	}

	-- Add API key as header or URL parameter based on the model
	local url = model_config.api_url
	if model_config.name:lower():match("gemini") then
		url = url .. "?key=" .. model_config.api_key
	else
		headers["Authorization"] = "Bearer " .. model_config.api_key
	end

	-- Make API request
	local response, err = utils.http_request(url, "POST", headers, body)

	if err then
		return "Error: " .. err
	end

	-- Extract response based on API format
	if response then
		if response.candidates and response.candidates[1] and response.candidates[1].content then
			-- Gemini format
			local parts = response.candidates[1].content.parts
			if parts and parts[1] and parts[1].text then
				return parts[1].text
			end
		elseif response.choices and response.choices[1] and response.choices[1].message then
			-- OpenAI format
			return response.choices[1].message.content
		elseif response.error then
			-- Error response
			return "Error: " .. vim.inspect(response.error)
		end
	end

	return "Error: Failed to parse model response"
end

-- Query Ollama-hosted models
function ai_assist.query_ollama_model(model_config, context, query)
	-- Check if Ollama is running
	if not utils.check_ollama_running() then
		return "Error: Ollama is not running. Please start the Ollama service."
	end

	-- Prepare prompt based on template if provided
	local prompt
	if model_config.template then
		prompt = model_config.template:gsub("{{ .Prompt }}", context .. "\n\nUser query: " .. query)
	else
		prompt = context .. "\n\nUser query: " .. query
	end

	-- Prepare request payload
	local payload = {
		model = model_config.model,
		prompt = prompt,
		stream = false,
	}

	-- Add parameters if specified
	if model_config.parameters then
		for k, v in pairs(model_config.parameters) do
			payload[k] = v
		end
	end

	-- Convert to JSON
	local body = vim.json.encode(payload)

	-- Prepare headers
	local headers = {
		["Content-Type"] = "application/json",
	}

	-- Make API request
	local response, err = utils.http_request(model_config.url, "POST", headers, body)

	if err then
		return "Error: " .. err
	end

	-- Extract response based on Ollama format
	if response then
		if response.response then
			return response.response
		elseif response.error then
			return "Error: " .. response.error
		end
	end

	return "Error: Failed to parse Ollama response"
end

-- Query function (entry point from user command)
function ai_assist.query()
	-- Open assistant if not already open
	if not state.active then
		ai_assist.open()
	end

	-- Focus input window
	if state.input_win and api.nvim_win_is_valid(state.input_win) then
		api.nvim_set_current_win(state.input_win)
		cmd("startinsert!")
	end
end

-- Function to explain selected code
function ai_assist.explain_selection()
	-- Get the visual selection
	local code = utils.get_visual_selection()
	if code == "" then
		vim.notify("No code selected", vim.log.levels.WARN)
		return
	end

	-- Open assistant
	if not state.active then
		ai_assist.open()
	end

	-- Set up the query
	local query = config.system_messages.code_explanation .. "\n\n```\n" .. code .. "\n```"

	-- Process the query
	ai_assist.process_query(query)

	-- Focus on main window to see the response
	if state.win and api.nvim_win_is_valid(state.win) then
		api.nvim_set_current_win(state.win)
	end
end

-- Function to improve selected code
function ai_assist.improve_selection()
	-- Get the visual selection
	local code = utils.get_visual_selection()
	if code == "" then
		vim.notify("No code selected", vim.log.levels.WARN)
		return
	end

	-- Open assistant
	if not state.active then
		ai_assist.open()
	end

	-- Set up the query
	local query = "Review and improve the following code. Consider optimizations, best practices, and potential bugs:\n\n```\n"
		.. code
		.. "\n```"

	-- Process the query
	ai_assist.process_query(query)

	-- Focus on main window to see the response
	if state.win and api.nvim_win_is_valid(state.win) then
		api.nvim_set_current_win(state.win)
	end
end

-- Function to select model
function ai_assist.select_model()
	-- Prepare model choices
	local choices = {}
	local model_names = {}

	for name, model in pairs(config.models) do
		table.insert(choices, model.icon .. " " .. model.name)
		table.insert(model_names, name)
	end

	-- Display selection menu using vim.ui.select
	vim.ui.select(choices, {
		prompt = "Select AI Model:",
		format_item = function(item)
			return item
		end,
	}, function(choice, idx)
		if choice then
			-- Update selected model
			state.selected_model = model_names[idx]

			-- Update header if window is open
			if state.buf and api.nvim_buf_is_valid(state.buf) then
				local header = utils.generate_header()

				-- Keep rest of buffer content
				local current_lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
				local content_start = 0

				-- Find the header end
				for i, line in ipairs(current_lines) do
					if line == "" and i > 5 then
						content_start = i
						break
					end
				end

				-- Create new buffer content
				local new_lines = {}
				for i, line in ipairs(header) do
					new_lines[i] = line
				end

				-- Add existing content
				for i = content_start, #current_lines do
					table.insert(new_lines, current_lines[i])
				end

				-- Update buffer
				api.nvim_buf_set_lines(state.buf, 0, -1, false, new_lines)
			end

			-- Notify user
			vim.notify("AI model changed to " .. config.models[state.selected_model].name, vim.log.levels.INFO)
		end
	end)
end

-- Function to add context from current buffer
function ai_assist.add_context()
	-- Get file path and content
	local filepath = api.nvim_buf_get_name(0)
	local filename = filepath:match("([^/\\]+)$") or "untitled"
	local content = utils.get_current_buffer_content()

	-- Check if we already have this file in context
	for i, file_info in ipairs(state.context_files) do
		if file_info.name == filename then
			-- Update content
			state.context_files[i].content = content
			vim.notify("Updated context for " .. filename, vim.log.levels.INFO)
			return
		end
	end

	-- Add to context files
	table.insert(state.context_files, {
		name = filename,
		content = content,
	})

	-- Update header if window is open
	if state.buf and api.nvim_buf_is_valid(state.buf) then
		-- Update buffer to show context files
		local header = utils.generate_header()

		-- Add context files info
		table.insert(header, config.ui.icons.context .. "Context files: ")
		for i, file_info in ipairs(state.context_files) do
			local file_line = "  • " .. file_info.name
			table.insert(header, file_line)
		end
		table.insert(header, "")

		-- Keep rest of buffer content
		local current_lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
		local content_start = 0

		-- Find the content start (after header)
		for i, line in ipairs(current_lines) do
			if line == "Type your query below:" then
				content_start = i
				break
			end
		end

		-- Create new buffer content
		local new_lines = header

		-- Add prompt message
		table.insert(new_lines, "Type your query below:")
		table.insert(new_lines, "")

		-- Add existing content (after prompt message)
		if content_start > 0 then
			for i = content_start + 2, #current_lines do
				table.insert(new_lines, current_lines[i])
			end
		end

		-- Update buffer
		api.nvim_buf_set_lines(state.buf, 0, -1, false, new_lines)
	end

	vim.notify("Added " .. filename .. " to context", vim.log.levels.INFO)
end

-- Function to clear all context
function ai_assist.clear_context()
	-- Clear context files
	state.context_files = {}

	-- Update buffer if open
	if state.buf and api.nvim_buf_is_valid(state.buf) then
		local header = utils.generate_header()

		-- Keep chat history
		local current_lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
		local content_start = 0

		-- Find the content start (after header and context files)
		for i, line in ipairs(current_lines) do
			if line == "Type your query below:" then
				content_start = i
				break
			end
		end

		-- Create new buffer content
		local new_lines = header

		-- Add prompt message
		table.insert(new_lines, "Type your query below:")
		table.insert(new_lines, "")

		-- Add existing content (after prompt message)
		if content_start > 0 then
			for i = content_start + 2, #current_lines do
				table.insert(new_lines, current_lines[i])
			end
		end

		-- Update buffer
		api.nvim_buf_set_lines(state.buf, 0, -1, false, new_lines)
	end

	vim.notify("Cleared all context files", vim.log.levels.INFO)
end

-- Health check function
function ai_assist.health_check()
	local report = {
		"AI-Assist Health Check:",
		"--------------------",
		"Plugin version: 1.0.0",
		"",
		"Models configured:",
	}

	-- Check configured models
	for _, model in pairs(config.models) do
		local status = "✓"
		local notes = ""

		if model.type == "remote" then
			if not model.api_key or model.api_key == "" then
				status = "⚠"
				notes = " (API key not configured)"
			end
		elseif model.type == "ollama" then
			if not utils.check_ollama_running() then
				status = "⚠"
				notes = " (Ollama not running)"
			end
		end

		table.insert(report, string.format("  %s %s: %s%s", status, model.icon, model.name, notes))
	end

	-- Output report
	local buf = api.nvim_create_buf(false, true)
	api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	api.nvim_set_option_value("swapfile", false, { buf = buf })
	api.nvim_set_option_value("filetype", "markdown", { buf = buf })
	api.nvim_buf_set_name(buf, "AI Assistant Health Check")

	api.nvim_buf_set_lines(buf, 0, -1, false, report)

	-- Show in split
	cmd("vsplit")
	api.nvim_win_set_buf(0, buf)
end

return ai_assist
