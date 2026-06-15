#!/usr/bin/env bash
# Esconde a Waybar quando ha janela em FULLSCREEN no workspace ativo; mostra
# de volta ao sair. Escuta os eventos do Hyprland (socket2) e usa SIGUSR1
# (toggle de visibilidade da Waybar), sincronizando com o estado real.
# Iniciado no autostart do Hyprland.
exec python3 <<'PY'
import socket, os, json, subprocess

his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
rt  = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
sockpath = f"{rt}/hypr/{his}/.socket2.sock"

def has_fullscreen():
    try:
        out = subprocess.run(["hyprctl", "activeworkspace", "-j"],
                             capture_output=True, text=True).stdout
        return bool(json.loads(out).get("hasfullscreen"))
    except Exception:
        return False

shown = True  # a waybar comeca visivel
def sync():
    global shown
    want = not has_fullscreen()           # visivel quando NAO ha fullscreen
    if want != shown:
        subprocess.run(["pkill", "-USR1", "-x", "waybar"])  # toggle
        shown = want

# eventos que podem mudar o estado de fullscreen visivel
WATCH = ("fullscreen", "workspace", "focusedmon", "activewindowv2",
         "openwindow", "closewindow", "movewindow")

s = socket.socket(socket.AF_UNIX)
s.connect(sockpath)
sync()  # estado inicial
buf = b""
while True:
    data = s.recv(8192)
    if not data:
        break
    buf += data
    while b"\n" in buf:
        line, buf = buf.split(b"\n", 1)
        ev = line.decode(errors="ignore").split(">>", 1)[0]
        if ev in WATCH:
            sync()
PY
