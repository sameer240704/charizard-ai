local M = {}
local api = vim.api
local fn = vim.fn
local utils = require("ai-assist.core.utils")

M.buf = nil
M.win = nil

function M.setup()
	-- Set up autocmds for input handling
	local group = api.nvim_create_augroup("AIAssistInput", { clear = true })

	api.nvim_create_autocmd("BufEnter", {
		group = group,
		buffer = M.buf,
		callback = function()
			if M.win and api.nvim_win_is_valid(M.win) then
				api.nvim_set_current_win(M.win)
			end
		end,
	})
end

function M.create_window()
	if M.win and api.nvim_win_is_valid(M.win) then
		api.nvim_set_current_win(M.win)
		return
	end

	local config = require("ai-assist.core.config").ui
	local width = math.floor(vim.o.columns * config.width)

	-- Create new buffer if none exists or if existing is invalid
	if not M.buf or not api.nvim_buf_is_valid(M.buf) then
		M.buf = api.nvim_create_buf(false, true)
		api.nvim_set_option_value("filetype", "ai_assist_input", { buf = M.buf })
		api.nvim_set_option_value("buftype", "prompt", { buf = M.buf })
	else
		-- Clear existing buffer instead of creating new one
		api.nvim_buf_set_lines(M.buf, 0, -1, false, { "" })
	end

	-- Create input window
	M.win = api.nvim_open_win(M.buf, true, {
		relative = "editor",
		width = width,
		height = 3,
		col = config.position == "right" and (vim.o.columns - width) or 0,
		row = vim.o.lines - 4,
		style = "minimal",
		border = config.border,
		title = " Ask AI ",
		title_pos = "center",
	})

	-- Setup prompt
	fn.prompt_setprompt(M.buf, config.prompt_prefix)
	fn.prompt_setcallback(M.buf, function(text)
		if text and text ~= "" then
			require("ai-assist").process_query(text)
			api.nvim_buf_set_lines(M.buf, 0, -1, false, { config.prompt_prefix })
		end
	end)

	-- Focus on Input
	api.nvim_set_current_win(M.win)
	vim.cmd("startinsert!")

	-- Apply theme
	require("ai-assist.ui.theme").apply_theme(M.win, M.buf)

	-- Keymaps
	local opts = { noremap = true, silent = true, buffer = M.buf }
	vim.keymap.set("i", "<CR>", '<Cmd>lua require("ai-assist.ui.input").submit()<CR>', opts)
	vim.keymap.set("i", "<C-c>", '<Cmd>lua require("ai-assist.ui.window").close()<CR>', opts)
end

function M.submit()
	local lines = api.nvim_buf_get_lines(M.buf, 0, -1, false)
	local text = table.concat(lines, "\n"):gsub("^" .. vim.fn.prompt_getprompt(M.buf), "")

	if text ~= "" then
		-- Clear input before processing
		api.nvim_buf_set_lines(M.buf, 0, -1, false, { vim.fn.prompt_getprompt(M.buf) })

		-- Process the query
		require("ai-assist").process_query(text)
	end
end

function M.close()
	if M.win and api.nvim_win_is_valid(M.win) then
		api.nvim_win_close(M.win, true)
		M.win = nil
	end
	if M.buf and api.nvim_buf_is_valid(M.buf) then
		api.nvim_buf_delete(M.buf, { force = true })
		M.buf = nil
	end
end

return M
