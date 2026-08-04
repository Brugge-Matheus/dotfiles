#!/usr/bin/env bash
# Daemon leve: escuta os eventos do Hyprland (socket2) e manda a waybar
# atualizar os botoes de workspace (modulos custom/ws*, todos com "signal": 9)
# via SIGRTMIN+9. Assim a troca/abertura/fechamento de janela reflete na hora.
# Iniciado no autostart do hyprland.lua. Reconecta sozinho se o socket cair.
exec python3 <<'PY'
import socket, os, time, subprocess

his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
rt  = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
sockpath = f"{rt}/hypr/{his}/.socket2.sock"

EV = ("workspace", "createworkspace", "destroyworkspace", "moveworkspace",
      "openwindow", "closewindow", "movewindow", "focusedmon", "activewindowv2")

def refresh():
    try: subprocess.run(["pkill", "-RTMIN+9", "waybar"])
    except Exception: pass

refresh()  # estado inicial
while True:
    try:
        s = socket.socket(socket.AF_UNIX)
        s.connect(sockpath)
    except Exception:
        time.sleep(1); continue
    buf = b""
    refresh()
    try:
        while True:
            data = s.recv(4096)
            if not data:
                break
            buf += data
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                ev = line.decode("utf-8", "ignore").split(">>", 1)[0]
                if ev in EV:
                    refresh()
    except Exception:
        pass
    finally:
        try: s.close()
        except Exception: pass
    time.sleep(1)  # reconecta
PY
