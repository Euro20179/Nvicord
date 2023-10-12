local cache = require"discord.cache"
local config = require"discord.config"

---@class discord.Server
---@field id string
---@field name string
---@field icon string?
---@field icon_hash string?
---@field splash string?
---@field discovery_splash string?
---@field owner boolean?
---@field owner_id discord.Snowflake
---@field permissions string
---@field region string?
---@field afk_channel_id discord.Snowflake?
---@field afk_timeout integer
---@field widget_enabled boolean?
---@field widget_channel_id discord.Snowflake?
---@field verification_level integer
---@field default_message_notifications integer
---@field explicit_content_filter integer
---@field roles discord.Role[]
---@field emojis discord.Emoji[]
---@field features discord.Features[]
---@field mfa_level integer
---@field application_id discord.Snowflake?
---@field system_channel_id discord.Snowflake?
---@field system_channel_flags integer
---@field rules_channel_id discord.Snowflake?
---@field max_presences integer?
---@field max_members integer?
---@field vanity_url_code string?
---@field description string?
---@field banner string?
---@field premium_tier integer
---@field premium_subscription_count integer?
---@field preferred_locale string
---@field public_updates_channel_id discord.Snowflake?
---@field max_video_channel_users integer?
---@field max_stage_video_channel_userse integer?
---@field approximage_member_count integer?
---@field approximate_presence_count integer?
---@field welcome_screen discord.WelcomeScreen?
---@field nsfw_level integer
---@field stickers discord.Sticker[]
---@field premium_progress_bar_enabled boolean
---@field safety_alerts_channel_id discord.Snowflake?

local _M = {}

---@return discord.Server[]? nil
---@param force boolean? If true, send a request to discord to fetch channels reguardless if there are channels in the cache
_M.get_servers = function(force)
    if cache.servers and not force then
        return cache.servers
    end
    local out = vim.system({ "curl", "-H", "Authorization: " .. config.token,
        "https://discord.com/api/v10/users/@me/guilds" }):wait()
    if out.code == 0 then
        cache.servers = vim.json.decode(out.stdout)
        return cache.servers
    end
end

---@param filter fun(server: discord.Server): boolean
---@return discord.Server[]
_M.get_servers_with_filter = function(filter)
    local ss = _M.get_servers()
    if not ss then
        return {}
    end
    local valid_servers = {}
    for _, server in ipairs(ss) do
        if filter(server) then
            valid_servers[#valid_servers + 1] = server
        end
    end
    return valid_servers
end

---@param id string | discord.Snowflake
---@return discord.Server?
_M.get_server_by_id = function(id)
    return _M.get_servers_with_filter(function(s)
        return s.id == id
    end)[1]
end

---@param on_select fun(selection: {id: string, name: string}): any
_M.select_server = function(on_select)
    local dis = require"discord"
    local servers = _M.get_servers(false)
    if not servers then
        return nil
    end
    dis.select_resource(servers, on_select)
end

return _M
