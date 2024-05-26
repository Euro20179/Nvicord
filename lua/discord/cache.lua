---@class discord._ServerCache
---@field channels discord.Channel[]

---@class discord._Cache
---@field servers discord.Server[]
---@field server_cache {[string]: discord._ServerCache}
local cache = {}
return cache
