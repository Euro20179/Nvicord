# Nvicord

At this point in time, this is more of a demonstration of an idea than a fully functional client library

However it does have the bare minimum to be able to interact with any channel in any server.

Sending dms is currently not possible, however if you are sent a dm, it will notify you

# Install

I recommend also installing [nvicord-ui](https://github.com/euro20179/nvicord-ui) which contains some bare bones ui for this library

## Requirements

- Python 3.10+

### Python modules
- [websockets](https://pypi.org/project/websockets/)
- [pynvim](https://pypi.org/project/pynvim/)

No lua modules are required.

---

This should work with a plugin manager

This is how I have it setup

After cloning add the following to your `init.lua`

```lua
local discordui = require"discord-ui"
discordui.setup{
    token = "YOUR DISCORD TOKEN HERE" --optional, if not provided, a prompt to login will be given
    user_id = "YOUR USER ID" --obtained by right clicking on your user in discord and clicking "copy user id", developer mode needs to be enabled for this
}
```

It is possible to use nvicord without the ui plugin

But it's just not meant for user interaction, and so it will be left undocumented here

If you really want to know, checkout the functions in `lua/discord/_discord.lua`

# Using

1. To open the client (if you are using nvicord-ui) run
```bash
nvim "discord://Server name here/Channel name here"
```

or

```bash
nvim "discord://id=server-id-here/id=channel-id-here"
```

2. After neovim opens, 2 buffers will be created, an /input buffer, and an /output buffer.
    - To see the buffers, use the `:ls` command
3. Only the /ouput buffer will be shown by default, to open the input buffer run `:lua require"discord-ui".display_channel()`
    - Select any buffer that contains the channel name/id you want to open
    - this will open a new tab with a split, top buffer containing the output, bottom buffer containing the input
4. To send a message, put something in the input buffer, and do `:lua require "discord".send_message_bind()`
    - I recommend binding this to a key (hence why the function has `bind` in the name)
    - this function makes sure you're in a discord:// input buffer, and sends the contents of the buffer to the channel you're in

Messages can also be sent by doing:
```lua
require"discord".send_message({content = "Text to send"}, "channel_id")
```
The first argument is a message object documented [here](https://discord.com/developers/docs/resources/channel#message-object), the second argument is the id of the channel to send the message to

More ui documentation will be at [nvicord-ui](https://github.com/euro20179/nvicord-ui)

# Goals

- [ ] Ability to delete messages in output buffer
- [ ] Ability to send attachments
- [ ] Ability to reply to messages
- [ ] Proper documentation
- [ ] Sending dms / ability to be in a dm channel
- [ ] Add highlights for output text (somewhat complete, usernames are highlighted)
- [ ] Support a plain discord:// uri
    - This would allow running `nvim discord://` which would open a server selection screen, then a channel selection screen
- [x] Server selection screen
- [x] Channel selection screen
- [x] Ability to login with username/password
- [x] Support server names/ channel names in discord:// uri

# Non-goals

- Stylistic interface
    - the goal is to create a minimal functional client where certain functions can be overwriten by the user that would give it a better interface
- Voice chat
     - I do not want to deal with this lol
