--discord:// uri
--discord://<server-ident>/<channel-ident>[/<type>]
--server-ident: server name | id=server-id
--channel-ident: channel name | id=channel-id
--type: output | input

---@alias discord.UriOutputType "output" | "input" | nil

local config = require "discord.config"

local servers = require "discord.resources.servers"
local channels = require "discord.resources.channels"

local _M = {}

local data = {}

local event_handlers = {
    MESSAGE_CREATE = function(MESSAGE_CREATE)
        if MESSAGE_CREATE.t ~= "MESSAGE_CREATE" then
            vim.cmd.echoerr("'did not get a MESSAGE_CREATE json'")
            return
        end
        local msgObj = MESSAGE_CREATE.d
        local guild_id = msgObj.guild_id
        if guild_id == nil and msgObj.author.id ~= config.user_id then
            _M.dm_notify(msgObj)
            return
        end
        local displayName = vim.NIL
        if msgObj.member then
            displayName = msgObj.member.nick
        end
        if displayName == vim.NIL then
            displayName = msgObj.author.username
        end
        if displayName == vim.NIL then
            displayName = "<UNKNOWN>"
        end

        local contentLines = vim.split(msgObj.content, "\n")
        local lines = { "@" .. displayName .. ": " .. contentLines[1] }
        for i = 2, #contentLines do
            lines[i] = contentLines[i]
        end

        local buffers = _M.get_channel_buffers(guild_id, msgObj.channel_id)

        if buffers.output_buf ~= nil then
            vim.api.nvim_buf_set_lines(buffers.output_buf, -1, -1, false, lines)
            local win_buf = vim.api.nvim_win_get_buf(0)
            if win_buf == buffers.output_buf then
                vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buffers.output_buf), 0 })
            end
        end
    end
}

local function discordSend(command_data)
    local channel_id = command_data.fargs[1]
    local content = vim.list_slice(command_data.fargs, 2)[1]
    _M.send_message({ content = content }, channel_id)
end

---@param resources {id: string | discord.Snowflake, name: string}[]
---@param on_select fun(selection: {id: string, name: string}): any
---This is a function that generically allows the user to select from a list of resources
---a "resource" is any object that has at least an id, and name field
---example use case: selecting from a list of servers
_M.select_resource = function(resources, on_select)
    --\x1e is the "record separator" ascii value, it's (almost) garanteed to not show up in a resource name
    -- it's also a logical seperator value to use
    local items = {}
    for _, resource in pairs(resources) do
        items[#items + 1] = resource.name .. " \x1e#" .. tostring(resource.id)
    end
    vim.ui.select(items, {
        prompt = "Select one"
    }, function(s)
        local name_and_id = vim.split(s, " \x1e#")
        on_select({ name = name_and_id[1], id = name_and_id[2] })
    end)
end

_M.dm_notify = function(msg)
    vim.notify("DM @" .. msg.author.username .. ": " .. msg.content)
end

_M.handle_discord_event = function(event)
    if event_handlers[event.t] then
        event_handlers[event.t](event)
    else
        vim.notify(tostring(event.t) .. " Has not been implemented", 1, {})
    end
end

_M.goto_channel = function()
    servers.select_server(function(server)
        channels.select_channel(server.id, function(channel)
            _M.open_uri("discord://id=" .. server.id .. "/id=" .. channel.id)
        end)
    end)
end

_M.clear_buf = function(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
end

_M.setup = function(opts)
    if not opts.token then
        error("No user token given")
        return
    end
    if not opts.user_id then
        error("No user id given")
        return
    end
    config.token = opts.token
    config.user_id = opts.user_id

    vim.filetype.add({
        pattern = {
            ["discord://.*"] = function(path, bufnr, ...)
                _M.start(path)
            end
        }
    })
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

---@param uri string
---@return discord.Server, discord.Channel, discord.UriOutputType
_M.parse_discord_uri = function(uri)
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
    return server, channel, type
end

---@param server_name string
---@param channel_name string
---@param channel_id string | discord.Snowflake
---@param replaceBuf integer?
---@return integer | buffer
local function create_input_buf(server_name, channel_name, channel_id, replaceBuf)
    local input_buf = replaceBuf or vim.api.nvim_create_buf(true, false)

    vim.api.nvim_buf_set_name(input_buf,
        "discord://" .. server_name .. "/" .. channel_name .. "/input")

    vim.keymap.set("n", "<leader>s", function()
        local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
        _M.send_message({ content = text }, channel_id)
        _M.clear_buf(input_buf)
    end, { buffer = input_buf })

    vim.keymap.set("i", "<c-s>", function()
        local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
        _M.send_message({ content = text }, channel_id)
        _M.clear_buf(input_buf)
    end, { buffer = input_buf })
    return input_buf
end

---@param server_name string
---@param channel_name string
---@param replaceBuf integer?
local function create_output_buf(server_name, channel_name, replaceBuf)
    local output_buf = replaceBuf or vim.api.nvim_create_buf(true, false)

    vim.api.nvim_buf_set_name(output_buf,
        "discord://" .. server_name .. "/" .. channel_name .. "/output")
end

---@param server_id string | discord.Snowflake
---@param channel_id string | discord.Snowflake
---@param buffer_type "output" | "input"
---@return integer | nil
local function get_channel_buffer_of_type(server_id, channel_id, buffer_type)
    for _, buf in pairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if vim.startswith(name, "discord://") then
            local uri_server, uri_channel, buf_type = _M.parse_discord_uri(name)
            if tostring(uri_server.id) == tostring(server_id) and tostring(uri_channel.id) == tostring(channel_id) and buf_type == buffer_type then
                return buf
            end
        end
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
            local uri_server, uri_channel, buf_type = _M.parse_discord_uri(name)
            if tostring(uri_server.id) == tostring(server_id) and tostring(uri_channel.id) == tostring(channel_id) then
                if buf_type == "output" then
                    resp.output_buf = buf
                elseif buf_type == "input" then
                    resp.input_buf = buf
                end
            end
        end
    end
    return resp
end

---Opens the input buffer for the current output buffer
_M.open_input_box = function()
    local name = vim.api.nvim_buf_get_name(0)
    if not vim.startswith(name, "discord://") then
        error("Not currently in a discord:// buffer")
    end
    local server, channel, buf_type = _M.parse_discord_uri(name)
    if buf_type ~= "output" then
        error("Not currently in an output buffer")
    end

    local input_buf = _M.get_channel_input_buffer(server.id, channel.id)

    if not input_buf then
        ---@diagnostic disable-next-line
        input_buf = create_input_buf(server.name, channel.name, channel.id)
    end

    vim.cmd.split()
    vim.api.nvim_win_set_buf(0, input_buf)
end

---@param uri string
---@param replaceBufs {output: integer, input: integer}?
_M.open_uri = function(uri, replaceBufs)
    local server, channel, buf_type = _M.parse_discord_uri(uri)

    if not channel then
        vim.notify("Not connecting to channel")
        return
    end

    local server_name = server.name
    local channel_name = channel.name or "UNKNOWN"

    if buf_type == "input" or buf_type == nil then
        --only replace input buf if the uri specfically says that it is loading an input buf
        local irbuf = buf_type == "input" and replaceBufs and replaceBufs.input or nil
        create_input_buf(server_name, channel_name, channel.id, irbuf)
    end
    if buf_type == "output" or buf_type == nil then
        local orbuf = replaceBufs and replaceBufs.output or nil
        create_output_buf(server_name, channel_name, orbuf)
    end
end

---@param uri string? should be a discord:// uri described at the top of _discord.lua
_M.start = function(uri)
    _M.open_uri(uri or "discord://", {
        output = 0,
        input = 0
    })
    if not data.started then
        vim.api.nvim_create_user_command("DiscordSend", discordSend, { nargs = "+" })
        vim.system({ "/home/euro/.config/nvim/lua/discord/main.py", vim.v.servername })
        data.started = true
    end
end

return _M
