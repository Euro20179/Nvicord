#!/bin/python
import json
import time
import threading
import neovim
import sys
import os
from websockets.exceptions import ConnectionClosedError
from websockets.sync.client import connect
from websockets.sync.connection import Connection

#TODO:
#this file is ONLY responsible for creating the websocket and heartbeat
#when it receives a new message it should send it to the discord nvim lua plugin to handle
#there shouldn't be any logic here

s = None

def mantainHeartbeat(ws: Connection, interval: int):
    while True:
        time.sleep(interval / 1000)
        try:
            if s is not None:
                ws.send(json.dumps({"op": 1, "d": s + 1}))
            else:
                ws.send(json.dumps({"op": 1, "d": None}))
        except ConnectionClosedError:
            break

def notify_test(nvim: neovim.Nvim):
    nvim.command("lua vim.notify('hi')")

if len(sys.argv) < 3:
    sys.stderr.write("Must provide a neovim sever and discord token\nmain.py <neovim-server> <discord-token>")
    exit(1)

ws = None
token = sys.argv[2]

nvim = neovim.attach("socket", path=sys.argv[1])


nvim.api.create_user_command("DiscordNotify", 'lua vim.notify("test")', {})

def handleDiscordWebSocketMessages(ws: Connection):
    global s
    nvim.exec_lua("discord = require'discord.events'")
    while True:
        msg = json.loads(ws.recv())
        if msg["s"]:
            s = msg["s"]
        nvim.lua.discord._handle_event(msg)

def main():
    global ws

    with connect("wss://gateway.discord.gg", max_size=2 ** 22) as ws:
        ws.send(json.dumps({"op":2,"d":{"token": token,"capabilities":16381,"properties":{"os":"Linux","browser":"Firefox","device":"","system_locale":"en-US","browser_user_agent":"Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/118.0","browser_version":"118.0","os_version":"","referrer":"","referring_domain":"","referrer_current":"","referring_domain_current":"","release_channel":"stable","client_build_number":235912,"client_event_source":None},"presence":{"status":"online","since":0,"activities":[],"afk":False},"compress":False,"client_state":{"guild_versions":{},"highest_last_message_id":"0","read_state_version":0,"user_guild_settings_version":-1,"user_settings_version":-1,"private_channels_version":"0","api_code_version":0}}}))
        msg = ws.recv()
        data = json.loads(msg)
        heartbeat_interval = data["d"]["heartbeat_interval"]
        thread = threading.Thread(target=mantainHeartbeat, args=(ws, heartbeat_interval))
        thread.start()
        handleDiscordWebSocketMessages(ws)


try:
    main()
except Exception as e:
    print(e)
    if ws:
        ws.close()
        exit()
