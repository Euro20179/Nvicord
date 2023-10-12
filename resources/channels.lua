---@class discord.Channel
---@field id discord.Snowflake
---@field type integer
---@field guild_id discord.Snowflake?
---@field position integer?
---@field permission_overwrites discord.Overwrite?
---@field name string?
---@field nsfw boolean?
---@field last_message_id discord.Snowflake?
---@field bitrate integer?
---@field user_limit integer?
---@field rate_limit_per_user integer?
---@field recipients discord.User[]?
---@field icon string?
---@field owner_id discord.Snowflake?
---@field application_id discord.Snowflake?
---@field managed boolean?
---@field parent_id discord.Snowflake?
---@field last_pin_timestamp string
---@field rtc_region string?
---@field video_quality_mode integer?
---@field message_count integer?
---@field member_count integer?
---@field thread_metadata discord.ThreadMetadata?
---@field member discord.ThreadMember?
---@field default_auto_archive_duration integer?
---@field permissions string?
---@field flags integer?
---@field total_message_sent integer?
---@field available_tags discord.Tag[]
---@field applied_tags discord.Snowflake[]
---@field default_reaction_emoji discord.DefaultReaction?
---@field default_thread_rate_limit_per_user integer?
---@field default_sort_order integer?
---@field default_forum_layout integer?

---@class discord.Overwrite
---@field id discord.Snowflake
---@field type integer
---@field allow string
---@field deny string

local cache = require"discord.cache"
local config = require"discord.config"

local _M = {}

---@param server_id string | discord.Snowflake
---@param filter fun(channel: discord.Channel): boolean
---@return discord.Channel[]
_M.get_channels_in_server_with_filter = function(server_id, filter)
    local channels = _M.get_channels_in_server(server_id)

    if not channels then
        return {}
    end

    local valid_channels = {}
    for _, channel in ipairs(channels) do
        if filter(channel) then
            valid_channels[#valid_channels + 1] = channel
        end
    end
    return valid_channels
end

---@param server_id string | discord.Snowflake
---@param channel_id string | discord.Snowflake
---@return discord.Channel | nil
_M.get_channel_in_server_by_id = function(server_id, channel_id)
    channel_id = tostring(channel_id)
    return _M.get_channels_in_server_with_filter(server_id, function(c)
        return tostring(c.id) == channel_id
    end)[1]
end

---@return discord.Channel[]?
_M.get_channels_in_server = function(server_id)
    local server_cache = cache[server_id]
    if server_cache and server_cache.channels then
        return server_cache.channels
    end
    local out = vim.system({ 'curl', "-H", "Authorization: " .. config.token,
        "https://discord.com/api/v10/guilds/" .. server_id .. "/channels" }):wait()
    if out.code == 0 then
        if server_cache == nil then
            cache[server_id] = {}
            server_cache = cache[server_id]
        end
        server_cache.channels = vim.json.decode(out.stdout)
        return server_cache.channels
    end
end


---@param server_id string | discord.Snowflake
---@param on_select fun(selection: {id: string, name: string}): any
_M.select_channel = function(server_id, on_select)
    local dis = require"discord"
    local channels = _M.get_channels_in_server(server_id)
    if not channels then
        return nil
    end
    dis.select_resource(channels, on_select)
end

return _M
