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
_M.get_members_in_server = function(server_id)
    if cache[server_id] then
        return cache[server_id]
    end
    local out = vim.system({ "curl", "-H", "Authorization: " .. config.token,
        "https://discord.com/api/v10/guilds/" .. tostring(server_id) .. "members" }):wait()
    if out.code == 0 then
        cache[server_id] = vim.json.decode(out.stdout)
        return cache[server_id]
    end
end

---@param server_id string | discord.Snowflake
---@param user_id string | discord.Snowflake
---@return discord.Member?
_M.get_member_in_server = function(server_id, user_id)
    server_id = tostring(server_id)
    user_id = tostring(user_id)
    local members = cache[server_id] or _M.get_members_in_server(server_id)
    for _, mem in pairs(members) do
        if not mem.user then
            goto continue
        end
        if mem.user.id == user_id then
            return mem
        end
        ::continue::
    end
    return nil
end

return _M
