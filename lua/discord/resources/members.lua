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

local roles = require"discord.resources.roles"

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
        "https://discord.com/api/v10/guilds/" .. tostring(server_id) .. "/members/" .. user_id }):wait()
    if out.code == 0 then
        cache[user_id] = vim.json.decode(out.stdout)
        return cache[user_id]
    end
    return nil
end

---@param member discord.Member
---@param user_id string
_M._add_member_to_cache = function(member, user_id)
    cache[user_id] = member
end

---@param guild_id string | discord.Snowflake
---@param user_id string | discord.Snowflake
_M.get_member_color_as_hex = function(guild_id, user_id)
    local member = _M.get_member_in_server(guild_id, user_id)
    if not member then
        return "000000"
    end
    local topRole = roles.get_role_in_server(guild_id,
        vim.fn.sort(member.roles or {}, function(r1, r2)
            local role1 = roles.get_role_in_server(guild_id, r1)
            local role2 = roles.get_role_in_server(guild_id, r2)
            return role2.position - role1.position
        end)[1])
    if topRole then
        local color = string.format("%.6X", topRole.color)
        return color
    end
    return "000000"
end

return _M
