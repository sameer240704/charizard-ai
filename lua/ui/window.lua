local M = {}
local api = vim.api
local fn = vim.fn
local utils = require("ai-assist.core.utils")

M.buf = nil
M.win = nil

function M.setup()
	-- Set up autocmds for window management
	local group = api.nvim_create_augroup("AIAssistWindow", { clear = true })

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
	-- Check for the validation of the current existing window
	if M.win and api.nvim_win_is_valid(M.win) then
		api.nvim_set_current_win(M.win)
		return
	end

	local config = require("ai-assist.core.config").ui
	local width = math.floor(vim.o.columns * config.width)
	local col = config.position == "right" and (vim.o.columns - width) or 0

	-- Reuse existing buffer if it exists and is still valid
	if M.buf and api.nvim_buf_is_valid(M.buf) then
		api.nvim_buf_set_lines(M.buf, 0, -1, false, {})
	else
		-- Create main buffer
		M.buf = api.nvim_create_buf(false, true)
		api.nvim_buf_set_name(M.buf, "AI Assist")
		api.nvim_set_option_value("filetype", "ai_assist", { buf = M.buf })
		api.nvim_set_option_value("buftype", "nofile", { buf = M.buf })
		api.nvim_set_option_value("modifiable", true, { buf = M.buf })
	end

	-- Create main window
	M.win = api.nvim_open_win(M.buf, true, {
		relative = "editor",
		width = width,
		height = vim.o.lines - 4,
		col = col,
		row = 1,
		style = "minimal",
		border = config.border,
		title = " AI Assistant ",
		title_pos = "center",
	})

	-- Apply theme and syntax
	require("ai-assist.ui.theme").apply_theme(M.win, M.buf)
	require("ai-assist.ui.syntax").setup()

	-- Keymaps
	local opts = { noremap = true, silent = true, buffer = M.buf }
	vim.keymap.set("n", "q", '<Cmd>lua require("ai-assist.ui.window").close()<CR>', opts)
	vim.keymap.set("n", "<Esc>", '<Cmd>lua require("ai-assist.ui.window").close()<CR>', opts)
end

function M.append_lines(lines)
	if not M.buf or not api.nvim_buf_is_valid(M.buf) then
		return
	end

	-- Convert lines to a flat list if they contain nested tables
	local flat_lines = {}
	for _, line in ipairs(lines) do
		if type(line) == "string" then
			-- Split strings with newlines into multiple lines
			for sub_line in line:gmatch("[^\n]+") do
				table.insert(flat_lines, sub_line)
			end
		else
			table.insert(flat_lines, tostring(line))
		end
	end

	local current = api.nvim_buf_get_lines(M.buf, 0, -1, false)
	api.nvim_buf_set_lines(M.buf, #current, #current, false, flat_lines)

	-- Auto-scroll if enabled
	if require("ai-assist.core.config").ui.auto_scroll then
		api.nvim_win_set_cursor(M.win, { api.nvim_buf_line_count(M.buf), 0 })
	end
end

function M.clear()
	if M.buf and api.nvim_buf_is_valid(M.buf) then
		api.nvim_buf_set_lines(M.buf, 0, -1, false, {})
	end
end

function M.close()
	if M.win and api.nvim_win_is_valid(M.win) then
		api.nvim_win_close(M.win, true)
		M.win = nil
	end

	-- EDIT: Not deleting the buffer here. Just clearing it
	if M.buf and api.nvim_buf_is_valid(M.buf) then
		api.nvim_buf_set_lines(M.buf, 0, -1, false, {})
		M.buf = nil
	end
end

return M
