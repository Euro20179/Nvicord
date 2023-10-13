--discord:// uri
--discord://<server-ident>/<channel-ident>[/<type>]
--server-ident: server name | id=server-id
--channel-ident: channel name | id=channel-id
--type: output | input

---@alias discord.UriOutputType "output" | "input" | nil

local config = require "discord.config"

local servers = require "discord.resources.servers"
local channels = require "discord.resources.channels"
local members = require "discord.resources.members"

local roles = require "discord.resources.roles"

local _M = {}

local data = {}

local role_hls = {}

local message_extmarks = {}

local event_handlers = {
    MESSAGE_DELETE = function(MESSAGE_DELETE)
        local msgObj = MESSAGE_DELETE.d
        local guild_id = msgObj.guild_id
        if guild_id == nil then
            return
        end
        local buffers = _M.get_channel_buffers(guild_id, msgObj.channel_id)

        local out = buffers.output_buf

        if out == nil then
            return
        end

        local msg_extmark = message_extmarks[msgObj.id]

        local extmark_pos = vim.api.nvim_buf_get_extmark_by_id(out, data.discord_msg_ns, msg_extmark[1], {})

        vim.api.nvim_buf_set_extmark(out, data.discord_hl_ns, extmark_pos[1], 0, {
            end_row = extmark_pos[1] + msg_extmark[2],
            hl_group = "DiscordStrike"
        })
    end,
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

        local color = "000000"

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
        local name_part = "@" .. displayName
        local lines = { name_part .. ": " .. contentLines[1] }
        for i = 2, #contentLines do
            lines[i] = contentLines[i]
        end

        local buffers = _M.get_channel_buffers(guild_id, msgObj.channel_id)

        if buffers.output_buf == nil then
            return
        end

        if msgObj.member.roles then
            members._add_member_to_cache(msgObj.member, msgObj.author.id)
            color = members.get_member_color_as_hex(guild_id, msgObj.author.id)
        end

        if not role_hls[color] then
            vim.api.nvim_set_hl(data.discord_hl_ns, "Discord" .. color, {
                link = "Normal"
            })
            vim.cmd.highlight("Discord" .. color .. " guifg=#" .. color)
            role_hls[color] = true
        end

        vim.api.nvim_buf_set_lines(buffers.output_buf, -1, -1, false, lines)

        local line_count = vim.api.nvim_buf_line_count(buffers.output_buf)

        local message_extmark = vim.api.nvim_buf_set_extmark(buffers.output_buf, data.discord_msg_ns, line_count - 1, 0,
            {})

        message_extmarks[msgObj.id] = {
            message_extmark,
            #lines
        }

        vim.api.nvim_buf_add_highlight(buffers.output_buf, data.discord_hl_ns, "Discord" .. color, line_count - #lines, 0,
            #name_part)

        local win_buf = vim.api.nvim_win_get_buf(0)

        if win_buf == buffers.output_buf then
            vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buffers.output_buf), 0 })
        end
    end
}

local function discordSend(command_data)
    local channel_id = command_data.fargs[1]
    local content = vim.list_slice(command_data.fargs, 2)[1]
    _M.send_message({ content = content }, channel_id)
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

_M.handle_discord_event = function(event)
    if event_handlers[event.t] then
        event_handlers[event.t](event)
    else
        -- vim.system({"notify-send", tostring(event.t)})
        -- vim.notify(tostring(event.t) .. " Has not been implemented")
    end
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
                _M.open_uri("discord://id=" .. server.id .. "/id=" .. channel.id)
            end)
        end)
    end
end

_M.clear_buf = function(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
end

_M.setup = function(opts)
    if not opts.user_id then
        error("No user id given")
        return
    end
    config.token = opts.token
    config.user_id = opts.user_id

    local discord_hl_ns = vim.api.nvim_create_namespace("discord")
    local discord_msg_ns = vim.api.nvim_create_namespace("discord_messages")

    data.discord_hl_ns = discord_hl_ns
    data.discord_msg_ns = discord_msg_ns

    vim.cmd.highlight("DiscordStrike cterm=strikethrough gui=strikethrough")

    vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "discord://*",
        callback = function()
            local name = vim.api.nvim_buf_get_name(0)
            if not data.started then
                _M.start(name)
            else
                _M.open_uri(name)
            end
        end
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
        error("Not currently in a discord:// buffer")
    end
    local uri_result = _M.parse_discord_uri(name)
    if uri_result == nil then
        error("Not in an output buffer")
    end
    local server, channel, buf_type = _M.unpack_uri_result(uri_result)
    if buf_type ~= "output" then
        error("Not currently in an output buffer")
    end

    local input_buf = _M.get_channel_input_buffer(server.id, channel.id)

    if not input_buf then
        input_buf = create_input_buf(server.name, channel.name, channel.id)
    end

    --this split is to make it so that the output win can't scroll below the input float
    vim.cmd.split()
    vim.api.nvim_win_set_height(0, 10)

    vim.api.nvim_open_win(input_buf, true, {
        relative = "win",
        row = 0, col = 0,
        width = vim.api.nvim_win_get_width(0),
        height = vim.api.nvim_win_get_height(0),
        style = "minimal",
        border = "rounded"
    })
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

---@return string (the token)
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
        error("Failed to login, invalid username or password")
    end
    local response = vim.json.decode(login_resp.stdout)
    return response.token
end

---@param uri string? should be a discord:// uri described at the top of _discord.lua
_M.start = function(uri)
    if not data.started then
        if not config.token then
            local token = login()
            config.token = token
        end
        _M.open_uri(uri or "discord://", {
            output = 0,
            input = 0
        })
        vim.api.nvim_create_user_command("DiscordSend", discordSend, { nargs = "+" })
        vim.system({ "/home/euro/.config/nvim/lua/discord/main.py", vim.v.servername, config.token })
        data.started = true
    else
        error("Discord has already started")
    end
end

return _M
