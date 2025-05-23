local utils = require("ai-assist.core.utils")
local M = {}

function M.query(prompt, context)
    -- Ensure prompt is a string (converting the table to a string)
	local prompt_text = type(prompt) == "table" and table.concat(prompt, "\n") or tostring(prompt)
	local context_text = context and (type(context) == "table" and table.concat(context, "\n") or tostring(context))
		or ""
	-- local config = require("ai-assist.core.config").get_model("gemini")
	local config = require("ai-assist.core.config").models.gemini

	if not config or not config.api_key then
		return nil, "Gemini API Key not configured"
	end

	local payload = {
		contents = {
			{
				parts = {
					-- { text = context .. "\n\n" .. prompt },
                    {
                        text = context_text ~= "" and (context_text .. "\n\n" .. prompt_text) or prompt_text
                    }
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
		-- Adding the Gemini safety settings
		safetySettings = config.safety_settings or {},
	}

	local body = vim.json.encode(payload)

	local headers = {
		["Content-Type"] = "application/json",
		["Accept"] = "application/json",
	}

	local url = config.api_url .. "?key=" .. config.api_key
	local response, err = utils.http_request(url, "POST", headers, body)

	if err then
		return nil, "Gemini API error: " .. tostring(err)
	end

	if response and response.candidates and response.candidates[1] then
		local content = response.candidates[1].content
		if content and content.parts and content.parts[1] then
			return content.parts[1].text
		end
	end

	return nil, "Invalid response format from Gemini API"
end

return M
