---@class discord.User
---@field username string
---@field discriminator string
---@field global_name string?
---@field avatar string?
---@field bot boolean?
---@field system boolean?
---@field mfa_enabled boolean?
---@field banner string?
---@field accent_color integer?
---@field locale string?
---@field verified boolean?
---@field email string?
---@field flags integer?
---@field premium_type integer?
---@field public_flags integer?
---@field avatar_decoration string?

local config = require"discord.config"

local _M = {}

local cache = {}

---@param user_id string
---@return discord.User?
_M.get_user = function(user_id)
    if cache[user_id] then
        return cache[user_id]
    end
    local out = vim.system({ "curl", "-H", "Authorization: " .. config.token,
        "https://discord.com/api/v10/users/" .. user_id }):wait()
    if out.code == 0 then
        cache[user_id] = vim.json.decode(out.stdout)
        return cache[user_id]
    end
end

return _M
