local M = {}
local base = require("ai-assist.models.base")
local utils = require("ai-assist.core.utils")

-- Registered model implementations
local model_implementations = {
	ollama = require("ai-assist.models.ollama"),
	remote = require("ai-assist.models.gemini"),
}

-- Create appropriate model instance based on config
function M.create_model(model_name)
	local config = require("ai-assist.core.config").models[model_name]
	if not config then
		return nil, "Model not found: " .. model_name
	end

	local implementation = model_implementations[config.type]
	if not implementation then
		return nil, "No implementation for model type: " .. config.type
	end

	-- Create base model and mixin implementation
	local model = base.BaseModel:new(config)
	for k, v in pairs(implementation) do
		model[k] = v
	end

	return model
end

-- Get list of available models
function M.list_models()
	local config = require("ai-assist.core.config")
	local models = {}
	for name, _ in pairs(config.models) do
		table.insert(models, name)
	end
	return models
end

-- Execute query with proper model
function M.query(model_name, prompt, context_files)
	local model, err = M.create_model(model_name)
	if not model then
		return nil, err
	end

	-- Format context if provided
	local context = model:format_context(context_files)

	-- Execute the query
	local response, err = model:query(prompt, context)
	if err then
		return nil, err
	end

	return model:clean_response(response)
end

-- Model selection UI
function M.select_model(callback)
	local config = require("ai-assist.core.config")
	local choices = {}
	local model_names = {}

	for name, model_cfg in pairs(config.models) do
		table.insert(choices, model_cfg.icon .. " " .. model_cfg.name)
		table.insert(model_names, name)
	end

	vim.ui.select(choices, {
		prompt = "Select AI Model:",
		format_item = function(item)
			return item
		end,
	}, function(_, idx)
		if idx and callback then
			callback(model_names[idx])
		end
	end)
end

-- Health check all models
function M.health_check()
	local results = {}
	for name, _ in pairs(require("ai-assist.core.config").models) do
		local model = M.create_model(name)
		if model then
			results[name] = {
				available = model:health_check(),
				type = model.type,
			}
		end
	end
	return results
end

return M
