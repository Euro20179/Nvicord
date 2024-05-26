local _M = {}

---@enum Event
local Events = {
    READY = "READY",
    PRESENCE_UPDATE = "PRESENCE_UPDATE",
    MESSAGE_REACTION_ADD = "MESSAGE_REACTION_ADD",
    VOICE_STATE_UPDATE = "VOICE_STATE_UPDATE",
    GUILD_MEMBER_UPDATE = "GUILD_MEMBER_UPDATE",
    TYPING_START = "TYPING_START",
    CONVERSATION_SUMMARY_UPDATE = "CONVERSATION_SUMMARY_UPDATE",
    MESSAGE_DELETE = "MESSAGE_DELETE",
    MESSAGE_CREATE = "MESSAGE_CREATE",
}

_M.Events = Events

---@type table<Event, function[]>
local events = {}

---@param event_name Event
---@param cb function
_M.listen = function (event_name, cb)
    if events[event_name] ~= nil then
        events[#events[event_name] + 1] = cb
    else
        events[event_name] = {cb}
    end
end

_M._handle_event = function (event)
    local name = event.t
    if events[name] ~= nil then
        for i = 1, #events[name] do
            events[name][i](event)
        end
    end
end

return _M
