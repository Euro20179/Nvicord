---@class discord.RoleTags
---@field bot_id discord.Snowflake
---@field integration_id discord.Snowflake
---@field premium_subscrible nil
---@field subscription_listing_id discord.Snowflake
---@field available_for_purchace nil
---@field guild_connections nil

---@class discord.Role
---@field id discord.Snowflake
---@field name string
---@field color integer
---@field hoist boolean
---@field icon string | nil
---@field unicode_emoji string | nil
---@field position integer
---@field permissions string
---@field managed boolean
---@field mentionable boolean
---@field tags discord.RoleTags
---@field flags integer

local config = require"discord.config"

local _M = {}

local cache = {}

---@param server_id string | discord.Snowflake
_M.get_roles_in_server = function(server_id)
    server_id = tostring(server_id)
    if cache[server_id] then
        return cache[server_id]
    end
    local out = vim.system({ "curl", "-H", "Authorization: " .. config.token,
        "https://discord.com/api/v10/guilds/" .. server_id .. "/roles" }):wait()
    if out.code == 0 then
        cache[server_id] = vim.json.decode(out.stdout)
        return cache[server_id]
    end
    return nil
end

---@param server_id string | discord.Snowflake
---@param role_id string | discord.Snowflake
---@return discord.Role?
---In a for loop for fetching a bunch of roles by role id, this is faster than using the /roles/role-id endpoint as it would have to make a request for every role
_M.get_role_in_server = function(server_id, role_id)
    local roles = cache[server_id] or _M.get_roles_in_server(server_id)
    for _, role in pairs(roles or {}) do
        if role.id == role_id then
            return role
        end
    end
    return nil
end


return _M
