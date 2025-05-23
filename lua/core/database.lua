local M = {}

local db_type = "mongodb"

function M.setup()
	local success, mongo = pcall(require, "mongo")
	if not success then
		error("MongoDB Driver required. Install with: luarocks install mongorover")
        return false
	end
	local ok, client = mongo.Client(vim.env.MONGO_URI)
    if not ok or not client then
        vim.notify("Failed to connect to MongoDB. Using in-memory storage.", vim.log.levels.WARN)
        return false
    end

	M.db = client:getDatabase("charizard_ai")
    if not M.db then
        vim.notify("Failed to get database. Using in-memory storage.", vim.log.levels.WARN)
        return false
    end

	-- Initialize collections with schema validation
	M.sessions = M.db:createCollection("sessions", {
		validator = {
			["$jsonSchema"] = {
				bsonType = "object",
				required = { "model", "created_at" },
				properties = {
					model = { bsonType = "string" },
					created_at = { bsonType = "date" },
					context_files = {
						bsonType = "array",
						items = {
							bsonType = "object",
							properties = {
								name = { bsonType = "string" },
								path = { bsonType = "string" },
								added_at = { bsonType = "date" },
							},
						},
					},
				},
			},
		},
	})

	M.history = M.db:createCollection("history", {
		validator = {
			["$jsonSchema"] = {
				bsonType = "object",
				required = { "session_id", "query", "response" },
				properties = {
					session_id = { bsonType = "objectId" },
					query = { bsonType = "string" },
					response = { bsonType = "string" },
					created_at = { bsonType = "date" },
				},
			},
		},
	})

	M.sessions:createIndex({ model = 1 })
	M.history:createIndex({ session_id = 1 })
	M.history:createIndex({ created_at = -1 })

    return true
end

function M.create_session(model_name)
	local result = M.sessions.insertOne({
		model = model_name,
		created_at = os.time(),
		context_files = {},
	})

	return result.inserted_id
end

function M.add_history(session_id, query, response)
	M.history.insertOne({
		session_id = session_id,
		query = query,
		response = response,
		created_at = os.time(),
	})
end

function M.get_history(session_id, limit)
	return M.history
		.find({
			session_id = session_id,
		})
		:sort({ created_at = -1 })
		:limit(limit or 20)
		:toArray()
end

-- TODO: Add a function for adding and retrieving the context files for the user
