# Neovim Discord Client

At this point in time, this is more of a demonstration of an idea than a functional client

However it does have the bare minimum to be able to interact with any channel in any server.

Sending dms is currently not possible, however if you are sent a dm, it will notify you

# Install

## Requirements

- Python 3.10+

### Python modules
- [websockets](https://pypi.org/project/websockets/)
- [pynvim](https://pypi.org/project/pynvim/)

No lua modules are required.

---

I Have no idea what would happen if you installed this with a plugin manager,

At the moment, I recommend the following

```bash
git clone https://github.com/euro20179/nvim-discord-client discord
cp -r discord ~/.config/nvim/lua
```

This is how I have it setup

After cloning add the following to your `init.lua`

```lua
local discord = require"discord"
discord.setup{
    token = "YOUR DISCORD TOKEN HERE" --optional, if not provided, a prompt to login will be given
    user_id = "YOUR USER ID" --obtained by right clicking on your user in discord and clicking "copy user id", developer mode needs to be enabled for this
}
```

# Using

1. To open the client run
```bash
nvim "discord://Server name here/Channel name here"
```

```bash
nvim "discord://id=server-id-here/id=channel-id-here"
```

2. After neovim opens, 2 buffers will be created, an /input buffer, and an /output buffer.
    - To see the buffers, use the `:ls` command
3. Only the /ouput buffer will be shown by default, to open the input buffer run `:lua require"discord".open_input_box()`
    - It is also possible to open the buffer manually with the `:buffer` command, however `open_input_box` creates a split,
    - and will probably create a nicer input box in the future

- The `/output` buffer is for displaying messages sent to the channel
- The `/input` buffer is for sending messages to a channel
    - To use the `/input` buffer, type a message, then in insert mode press `<C-s>` or in normal mode press `<leader>s`
        - currently this cannot be changed
- A message can also be sent with the following code

```lua
require"discord".send_message({content = "Text to send"}, "channel_id")
```
The first argument is a message object documented [here](https://discord.com/developers/docs/resources/channel#message-object), the second argument is the id of the channel to send the message to

# Goals

- [x] Ability to login with username/password
- [ ] Proper documentation
- [x] Server selection screen
- [x] Channel selection screen
- [ ] Sending dms / ability to be in a dm channel
- [ ] Add highlights for output text
- [ ] Support a plain discord:// uri
    - This would allow running `nvim discord://` which would open a server selection screen, then a channel selection screen
- [x] Support server names/ channel names in discord:// uri

# Non-goals

- Stylistic interface
    - the goal is to create a bare minimum client where certain functions can be overwriten by the user that would give it a better interface
- Voice chat
     - I do not want to deal with this lol
