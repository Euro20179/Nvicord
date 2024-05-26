--discord:// uri
--discord://<server-ident>/<channel-ident>[/<type>]
--server-ident: server name | id=server-id
--channel-ident: channel name | id=channel-id
--type: output | input

---@alias discord.UriOutputType "output" | "input" | nil
---
---@alias buffer integer

local config = require "discord.config"

local servers = require "discord.resources.servers"
local channels = require "discord.resources.channels"
local members = require "discord.resources.members"

local _M = {}

local started = false

local function discordSend(command_data)
    local channel_id = command_data.fargs[1]
    local content = vim.list_slice(command_data.fargs, 2)[1]
    _M.send_message({ content = content }, channel_id)
end

---@param server_id discord.Snowflake
---@param channel_id discord.Snowflake
---@return table
_M.find_server_channel_buf_pair = function (server_id, channel_id)
    local serverName = servers.get_server_by_id(server_id)
    local channelName = channels.get_channel_in_server_by_id(server_id, channel_id)

    local requiredBufPrefix = "discord://" .. serverName.name .. "/" .. channelName.name

    local chans = vim.iter(vim.api.nvim_list_bufs())
        :filter(function (buf)
            local name = vim.api.nvim_buf_get_name(buf)
            return vim.startswith(name, requiredBufPrefix)
        end)
        :totable()

    local inChannel = vim.iter(chans):find(function (b)
        local name = vim.api.nvim_buf_get_name(b)
        return vim.endswith(name, '/input')
    end)
    local outChannel = vim.iter(chans):find(function (b)
        local name = vim.api.nvim_buf_get_name(b)
        return vim.endswith(name, '/output')
    end)

    return { IN = inChannel, OUT = outChannel }
end

_M.get_focused_server_id = function()
    local name = vim.api.nvim_buf_get_name(0)
    if not vim.startswith(name, "discord://") then
        error("Not focused on a discord:// buffer")
    end

    local server = _M.unpack_uri_result(_M.parse_discord_uri(name) or {})

    return server and server.id or nil
end

_M.get_focused_channel_id = function()
    local name = vim.api.nvim_buf_get_name(0)
    if not vim.startswith(name, "discord://") then
        error("Not focused on a discord:// buffer")
    end
    local _, channel = _M.unpack_uri_result(_M.parse_discord_uri(name) or {})
    return channel and channel.id or nil
end

---@param resources {id: string, name: string}[]
---@param on_select fun(selection: {id: string, name: string}): any
---This is a function that generically allows the user to select from a list of resources
---a "resource" is any object that has at least an id, and name field
---example use case: selecting from a list of servers
_M.select_resource = function(resources, on_select)
    --\x1e is the "record separator" ascii value, it's (almost) garanteed to not show up in a resource name
    -- it's also a logical seperator value to use
    local items = {}
    for _, resource in pairs(resources) do
        resource.name = resource.name:gsub("\n", "\\n")
        items[#items + 1] = resource.name .. " \x1e#" .. tostring(resource.id)
    end

    vim.ui.select(items, {
        prompt = "Select one"
    }, function(s)
        if s == nil then
            return
        end
        local name_and_id = vim.split(s, " \x1e#")
        on_select({ name = name_and_id[1], id = name_and_id[2] })
    end)
end

_M.dm_notify = function(msg)
    vim.notify("DM @" .. msg.author.username .. ": " .. msg.content)
end

---@param server_id string | nil
_M.open_channel = function(server_id)
    if server_id then
        channels.select_channel(server_id, function(channel)
            _M.open_uri("discord://id=" .. server_id .. "/id=" .. channel.id)
        end)
    else
        servers.select_server(function(server)
            channels.select_channel(server.id, function(channel)
                print(server.id, channel.id)
                _M.open_uri("discord://id=" .. server.id .. "/id=" .. channel.id)
            end)
        end)
    end
end



local function clear_buf (buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
end

_M.setup = function(opts)
    if not opts.user_id then
        vim.notify("No discord user id given", vim.log.levels.ERROR)
        return
    end
    config.token = opts.token
    config.user_id = opts.user_id
end

_M.send_message = function(messageJson, channel_id)
    if not channel_id then
        vim.fn.echoerr("'No channel id'")
    end
    if type(messageJson.content) ~= "string" then
        vim.fn.echoerr("'expected string content'")
    end
    vim.system({ "curl", "-H", "Authorization: " .. config.token, "-H", "Content-Type: application/json", "-d",
        vim.json.encode(messageJson), "https://discord.com/api/v9/channels/" .. channel_id .. "/messages" })
end

---@param uri_result {[1]: discord.Server, [2]: discord.Channel, [3]: discord.UriOutputType}
_M.unpack_uri_result = function(uri_result)
    return uri_result[1], uri_result[2], uri_result[3]
end

---@param uri string
---@return {[1]: discord.Server, [2]: discord.Channel, [3]: discord.UriOutputType} | nil
_M.parse_discord_uri = function(uri)
    uri = vim.trim(uri)
    if uri == "discord://" then
        return nil
    end
    local uri_data = vim.split(uri, "/")
    local server_ident = uri_data[3]
    local channel_ident = uri_data[4]
    ---@type string | nil
    local type = uri_data[5] or nil
    if type and #type == 0 then
        type = nil
    end

    if not server_ident then
        error("No server identity", 1)
    end
    if not channel_ident then
        error("No channel identity", 1)
    end

    local server, channel
    if vim.startswith(server_ident, "id=") then
        local id = vim.split(server_ident, "id=")[2]
        server = servers.get_servers_with_filter(function(s)
            return s.id == id
        end)[1]
    else
        server = servers.get_servers_with_filter(function(s)
            return s.name == server_ident
        end)[1]
    end
    if server == nil then
        error("Server with ident " .. server_ident .. " not found")
    end
    if vim.startswith(channel_ident, "id=") then
        local id = vim.split(channel_ident, "id=")[2]
        channel = channels.get_channels_in_server_with_filter(server.id, function(c)
            return c.id == id
        end)[1]
    else
        channel = channels.get_channels_in_server_with_filter(server.id, function(c)
            return c.name == channel_ident
        end)[1]
    end
    return { server, channel, type }
end

---Used to bind a key to sending a message from a buffer
_M.send_message_bind = function ()
    local bName = vim.api.nvim_buf_get_name(0)

    if not vim.startswith(bName, "discord://") or not vim.endswith(bName, "/input") then
        vim.notify("You are not in a discord://*/input buffer", vim.log.levels.ERROR, {})
        return
    end

    local result = _M.parse_discord_uri(bName)

    if result == nil then
        vim.notify("Could not parse buffer's discord uri", vim.log.levels.ERROR, {})
        return
    end

    local chan = result[2]

    local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    _M.send_message({ content = text }, chan.id)

    clear_buf(0)
end

---@param server_name string | discord.Snowflake
---@param channel_name string
---@param channel_id string | discord.Snowflake
---@param replaceBuf integer?
---@return integer | buffer
local function create_input_buf(server_name, channel_name, channel_id, replaceBuf)
    local input_buf = replaceBuf or vim.api.nvim_create_buf(true, false)

    vim.api.nvim_set_option_value("filetype", "markdown", {
        buf = input_buf
    })

    vim.api.nvim_buf_set_name(input_buf,
        "discord://" .. server_name .. "/" .. channel_name .. "/input")

    return input_buf
end

---@param server_name string
---@param channel_name string
---@param replaceBuf integer?
local function create_output_buf(server_name, channel_name, replaceBuf)
    local output_buf = replaceBuf or vim.api.nvim_create_buf(true, false)

    vim.api.nvim_buf_set_name(output_buf,
        "discord://" .. server_name .. "/" .. channel_name .. "/output")
    return output_buf
end

---@param server_id string | discord.Snowflake
---@param channel_id string | discord.Snowflake
---@param buffer_type "output" | "input"
---@return integer | nil
local function get_channel_buffer_of_type(server_id, channel_id, buffer_type)
    for _, buf in pairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if vim.startswith(name, "discord://") then
            local result = _M.parse_discord_uri(name)
            if result == nil then
                goto continue
            end
            local uri_server, uri_channel, buf_type = _M.unpack_uri_result(result)
            if tostring(uri_server.id) == tostring(server_id) and tostring(uri_channel.id) == tostring(channel_id) and buf_type == buffer_type then
                return buf
            end
        end
        ::continue::
    end
    return nil
end

---@param uri string Must be a uri without the /output or /input at the end
---@return number | nil
_M.get_channel_output_win = function(uri)
    local server, channel = _M.unpack_uri_result(_M.parse_discord_uri(uri) or {})
    for _, win in pairs(vim.api.nvim_list_wins()) do
        local win_buf = vim.api.nvim_win_get_buf(win)
        local buf_name = vim.api.nvim_buf_get_name(win_buf)
        if not vim.startswith(buf_name, "discord://") then
            goto continue
        end
        local buf_s, buf_c, buf_type = _M.unpack_uri_result(_M.parse_discord_uri(buf_name) or {})
        if buf_s == server and buf_c == channel and buf_type == "output" then
            return win
        end
        ::continue::
    end
    return nil
end

---@param server_id string | discord.Snowflake
---@param channel_id string | discord.Snowflake
---@return integer | nil
_M.get_channel_output_buffer = function(server_id, channel_id)
    return get_channel_buffer_of_type(server_id, channel_id, "output")
end

---@param server_id string | discord.Snowflake
---@param channel_id string | discord.Snowflake
---@return integer | nil
_M.get_channel_input_buffer = function(server_id, channel_id)
    return get_channel_buffer_of_type(server_id, channel_id, "input")
end

---@param server_id string | discord.Snowflake
---@param channel_id string | discord.Snowflake
---@return {input_buf: integer | nil, output_buf: integer | nil}
_M.get_channel_buffers = function(server_id, channel_id)
    local channel = channels.get_channel_in_server_by_id(server_id, channel_id)
    if not channel then
        error(tostring(channel_id) .. " Is not a valid channel in server: " .. tostring(server_id))
    end
    local resp = {
        output_buf = nil,
        input_buf = nil
    }
    for _, buf in pairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if vim.startswith(name, "discord://") then
            local uri_result = _M.parse_discord_uri(name)
            if uri_result == nil then
                goto continue
            end
            local uri_server, uri_channel, buf_type = _M.unpack_uri_result(uri_result)
            if tostring(uri_server.id) == tostring(server_id) and tostring(uri_channel.id) == tostring(channel_id) then
                if buf_type == "output" then
                    resp.output_buf = buf
                elseif buf_type == "input" then
                    resp.input_buf = buf
                end
            end
        end
        ::continue::
    end
    return resp
end

---Opens the input buffer for the current output buffer
_M.open_input_box = function()
    local name = vim.api.nvim_buf_get_name(0)
    if not vim.startswith(name, "discord://") then
        vim.notify("Not currently in a discord:// buffer", vim.log.levels.ERROR)
        return
    end
    local uri_result = _M.parse_discord_uri(name)
    if uri_result == nil then
        vim.notify("Not in an output buffer", vim.log.levels.ERROR)
        return
    end
    local server, channel, buf_type = _M.unpack_uri_result(uri_result)
    if buf_type ~= "output" then
        vim.notify("Not in an output buffer", vim.log.levels.ERROR)
        return
    end

    local input_buf = _M.get_channel_input_buffer(server.id, channel.id)

    if not input_buf then
        input_buf = create_input_buf(server.name, channel.name, channel.id)
    end

    vim.cmd.split()
    vim.api.nvim_win_set_buf(0, input_buf)
    --
    -- vim.api.nvim_open_win(input_buf, true, {
    --     relative = "win",
    --     row = vim.api.nvim_win_get_height(0) - 3, col = 0,
    --     width = vim.api.nvim_win_get_width(0),
    --     height = 3,
    --     style = "minimal",
    --     border = "rounded"
    -- })
end

---@param uri string
---@param replaceBufs {output: integer, input: integer}?
_M.open_uri = function(uri, replaceBufs)
    local uri_result = _M.parse_discord_uri(uri)

    if uri_result == nil then
        return
    end

    local server, channel, buf_type = _M.unpack_uri_result(uri_result)

    if channel == nil then
        return
    end

    local server_name = server.name
    local channel_name = channel.name or "UNKNOWN"

    local input_buf = _M.get_channel_input_buffer(server.id, tostring(channel.id))
    local output_buf = _M.get_channel_output_buffer(server.id, tostring(channel.id))

    if not input_buf and (buf_type == "input" or buf_type == nil) then
        --only replace input buf if the uri specfically says that it is loading an input buf
        local irbuf = buf_type == "input" and replaceBufs and replaceBufs.input or nil
        input_buf = create_input_buf(server_name, channel_name, channel.id, irbuf)
    end
    if not output_buf and (buf_type == "output" or buf_type == nil) then
        local orbuf = replaceBufs and replaceBufs.output or nil
        output_buf = create_output_buf(server_name, channel_name, orbuf)
    end

    return input_buf, output_buf
end

---@return string, string
_M.prompt_login = function()
    local email = vim.fn.input({ prompt = "Email: " })
    local password = vim.fn.inputsecret("Password: ")
    return email, password
end

---@return string | nil (the token)
local function login()
    local email, password = _M.prompt_login()
    local login_resp = vim.system({
        "curl",
        "-H", "Accept: */*",
        '-H', "Accept-Language: en-US,en;q=0.5",
        "-H", "Connection: keep-alive",
        "-H", "Content-Type: application/json",
        "-X", "POST",
        "-d", vim.json.encode({
        login = email,
        password = password,
        undelete = false --wtf is this
    }),
        "https://discord.com/api/v9/auth/login"
    }):wait()
    if login_resp.code ~= 0 then
        vim.notify("Failed to login, invalid username or password", vim.log.levels.ERROR)
        return nil
    end
    local response = vim.json.decode(login_resp.stdout)
    return response.token
end



---@param uri string? should be a discord:// uri described at the top of _discord.lua
_M.start = function(uri)
    if not started then
        if not config.token then
            local token = login()
            if token then
                config.token = token
            else
                vim.notify("Failed to start discord client", vim.log.levels.ERROR)
                return
            end
        end
        _M.open_uri(uri or "discord://", {
            output = 0,
            input = 0
        })
        vim.api.nvim_create_user_command("DiscordSend", discordSend, { nargs = "+" })
        --gets the containing filepath for this file
        local dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
        vim.system({dir .. "/main.py", vim.v.servername, config.token })
        started = true
    else
        vim.notify("Discord client already started", vim.log.levels.WARN)
    end
end

_M.has_started = function ()
    return started
end

return _M
