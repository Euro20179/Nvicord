---@alias discord.Snowflake integer

local _M = {}

---@param snowflake discord.Snowflake
_M.parse_snowflake = function(snowflake)
    local timestamp = bit.rshift(snowflake, 22)
    return timestamp
end
