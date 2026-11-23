#!/usr/bin/env bash
# Daemon leve: escuta os eventos do Hyprland (socket2) e manda a waybar
# atualizar os botoes de workspace (modulos custom/ws*, todos com "signal": 9)
# via SIGRTMIN+9. Assim a troca/abertura/fechamento de janela reflete na hora.
# Iniciado no autostart do hyprland.lua. Reconecta sozinho se o socket cair.
exec python3 <<'PY'
import socket, os, time, subprocess

rt  = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")

def find_sock():
    """socket de eventos da instancia atual do Hyprland (a variavel pode faltar/estar velha como servico)"""
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    p = f"{rt}/hypr/{his}/.socket2.sock"
    if his and os.path.exists(p):
        return p
    d = f"{rt}/hypr"
    c = [x for x in (os.listdir(d) if os.path.isdir(d) else []) if os.path.exists(f"{d}/{x}/.socket2.sock")]
    c.sort(key=lambda x: os.path.getmtime(f"{d}/{x}/.socket2.sock"))
    return f"{d}/{c[-1]}/.socket2.sock" if c else p

EV = ("workspace", "createworkspace", "destroyworkspace", "moveworkspace",
      "openwindow", "closewindow", "movewindow", "focusedmon", "activewindowv2")

def refresh():
    try: subprocess.run(["pkill", "-RTMIN+9", "waybar"])
    except Exception: pass

refresh()  # estado inicial
while True:
    try:
        s = socket.socket(socket.AF_UNIX)
        s.connect(find_sock())
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
