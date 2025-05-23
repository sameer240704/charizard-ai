local M = {}
local api = vim.api

M.colors = {
	dark = {
		bg = "#282c34",
		fg = "#abb2bf",
		border = "#3e4452",
		prompt = "#56b6c2",
		response = "#98c379",
		code = "#e5c07b",
		header = "#61afef",
	},
	light = {
		bg = "#f8f8f8",
		fg = "#383a42",
		border = "#e1e1e1",
		prompt = "#4078f2",
		response = "#50a14f",
		code = "#c18401",
		header = "#a626a4",
	},
}

function M.setup()
	-- Create highlight groups
	for theme, colors in pairs(M.colors) do
		for name, color in pairs(colors) do
			api.nvim_set_hl(0, "AIAssist" .. name:gsub("^%l", string.upper), {
				fg = color,
				bg = theme == "dark" and colors.bg or nil,
			})
		end
	end
end

function M.apply_theme(win, buf)
	local config = require("ai-assist.core.config").ui
	local theme = config.theme or "dark"
	local colors = M.colors[theme]

	-- Window styling
	api.nvim_set_option_value(
		"winhighlight",
		table.concat({
			"Normal:AIAssistBg",
			"FloatBorder:AIAssistBorder",
			"CursorLine:Visual",
			"SignColumn:SignColumn",
		}, ","),
		{ win = win }
	)

	-- Buffer styling
	api.nvim_set_option_value("syntax", "on", { buf = buf })
	-- Set window-local options (including conceallevel)
	api.nvim_set_option_value("conceallevel", 2, { win = win }) -- Changed from buf to window

	-- Apply colors
	api.nvim_set_hl(0, "AIAssistBg", { bg = colors.bg })
	api.nvim_set_hl(0, "AIAssistBorder", { fg = colors.border })
end

return M
