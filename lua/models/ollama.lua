local utils = require("ai-assist.core.utils")
local M = {}

local DEFAULT_PARAMS = {
	temperature = 0.5,
	top_p = 0.9,
	top_k = 40,
	num_ctx = 4096,
	stop = { "<|endoftext|>", "[/INST]" },
	num_predict = 1024,
}

-- For checking the status and health of ollama server
function M.check_model_available(model_name)
    local config = require('ai-assist.core.config').get_model(model_name)
    local url = (config.url or "http://localhost:11434") .. "/api/tags"

    local response, err = utils.http_request(url, "GET")
    if err then
        return false, "Connection failed: " .. err
    end

    if response and response.models then
        for _, model in pairs(response.models) do
            if model.name == config.model then
                return true
            end
        end

        return false, "Model not loaded. Run ollama pull " .. config.model
    end

    return false, "Could not verify model status"
end

function M.query(prompt, context, model_name)
	local config = require("ai-assist.core.config").get_model(model_name)

	if not utils.check_ollama_running() then
		return nil, "Ollama service is not running. Start with :systemctl start ollama or ollama serve"
	end

	local system_msg = config.system_message or "You're a precise coding assistant."
	local full_prompt =
		string.format("[INST] <<SYS>>\n%s\n<</SYS>>\n\n%s %s [/INST]", system_msg, context or "", prompt)

	local payload = {
		model = config.model,
		prompt = full_prompt,
		stream = false,
		options = vim.tbl_extend("force", DEFAULT_PARAMS, config.parameters or {}),
	}

    local headers = {
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json",
    }

    local url = config.url or "http://localhost:11434/api/generate"
    local response, err = utils.http_request(url, "POST", headers, vim.json.encode(payload))

    if err then
        return nil, "Ollama connection failed: " .. err
    end

    if not response then
        return nil, "Empty response from Ollama"
    end

    if response.error then
        return nil, "Ollama error: " .. response.error
    end

    if response.response then
        local cleaned = response.response:gsub("^%s*[/INST]%s*", ""):gsub("<%|endoftext%|>", "")
        return cleaned
    end

    return nil, "Unexpected response format"
end

return M
