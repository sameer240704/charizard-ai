local utils = require("ai-assist.core.utils")
local M = {}

function M.query(prompt, context)
	local config = require("ai-assist.core.config").get_model("gemini")

	local payload = {
		contents = {
			{
				parts = {
					{ text = context .. "\n\n" .. prompt },
				},
			},
		},

		generattionConfig = {
			temperature = config.temperature or 0.7,
			topP = config.top_p or 0.95,
			topK = config.top_k or 40,
			maxOutputTokens = config.max_tokens or 4096,
			stopSequence = config.stop_sequence or {},
		},
	}

	local body = vim.json.encode(payload)

	local headers = {
		["Content-Type"] = "application/json",
		["Accept"] = "application/json",
	}

    local url = config.api_url .. "?key=" .. config.api_key
    local response, err = utils.http_request(url, "POST", headers, body)

    if err then
        vim.notify("Gemini Error: " .. tostring(err), vim.log.levels.WARN)
    end

    return response
end

return M
