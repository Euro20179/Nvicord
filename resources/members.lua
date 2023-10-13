---@class discord.Member
---@field user discord.User?
---@field nick string?
---@field avatar string?
---@field roles discord.Snowflake[]?
---@field joined_at string
---@field premium_since string?
---@field deaf boolean
---@field mute boolean
---@field flags integer
---@field pending boolean?
---@field permissions string?
---@field communication_disabled_until integer?

local config = require "discord.config"

local _M = {}
---@type {[string]: discord.Member[]}
local cache = {}

---@param server_id string | discord.Snowflake
---@param user_id string | discord.Snowflake
---@return discord.Member?
_M.get_member_in_server = function(server_id, user_id)
    server_id = tostring(server_id)
    user_id = tostring(user_id)
    if cache[user_id] then
        return cache[user_id]
    end
    local out = vim.system({ "curl", "-H", "Authorization: " .. config.token,
        "https://discord.com/api/v10/guilds/" .. tostring(server_id) .. "/members/" .. user_id}):wait()
    if out.code == 0 then
        cache[user_id] = vim.json.decode(out.stdout)
        return cache[user_id]
    end
    return nil
end

return _M
