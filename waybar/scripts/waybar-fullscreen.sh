#!/usr/bin/env bash
# Waybar por-monitor com auto-hide em FULLSCREEN e revelar-ao-hover no topo.
#
# Por que uma instancia por monitor?
#   A Waybar roda como UM processo com uma barra por saida, e o SIGUSR1 (toggle
#   de visibilidade) atinge TODAS as barras de uma vez. Para esconder/revelar
#   cada monitor de forma INDEPENDENTE, lancamos uma instancia separada por
#   monitor, cada uma fixada a sua saida (wrapper que da "output" + include do
#   config.jsonc compartilhado, em $XDG_RUNTIME_DIR/waybar/<saida>.jsonc).
#
# Comportamento (por monitor, isolado):
#   - Sem fullscreen naquele monitor: a barra dele fica normal (reserva 32px).
#   - Com fullscreen naquele monitor: a barra dele some; encostar o mouse no
#     TOPO *desse* monitor a revela (overlay), descer esconde. Os outros
#     monitores nao sao afetados.
#
# Robustez: a visibilidade e dirigida pelo estado REAL (reserva do monitor),
# nao por um flag interno -> imune a dessincronia do toggle SIGUSR1.
# Lanca as barras no inicio e reage a conexao/desconexao de monitores.
# Iniciado no autostart do Hyprland (substitui o "waybar" direto).
exec python3 <<'PY'
import socket, os, json, subprocess, select, time, signal

HOME = os.environ["HOME"]
his  = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
rt   = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
sockpath = f"{rt}/hypr/{his}/.socket2.sock"

RUNDIR      = f"{rt}/waybar"
MAIN_CONFIG = f"{HOME}/.config/waybar/config.jsonc"
STYLE       = f"{HOME}/.config/waybar/style.css"

REVEAL_AT  = 2     # cursor a <= 2px do topo do monitor -> revela a barra dele
HIDE_BELOW = 40    # cursor a >= 40px do topo -> esconde (histerese > altura da barra)
POLL       = 0.10  # polling do cursor enquanto algum monitor estiver em fullscreen
SETTLE     = 0.25  # apos um toggle, espera propagar antes da proxima leitura

def hctl(*args):
    try:
        out = subprocess.run(["hyprctl", *args, "-j"],
                             capture_output=True, text=True).stdout
        return json.loads(out)
    except Exception:
        return None

def monitors():        return hctl("monitors") or []
def cursor():          return hctl("cursorpos") or {}
def ws_fullscreen():   # id do workspace -> hasfullscreen
    return {w["id"]: bool(w.get("hasfullscreen"))
            for w in (hctl("workspaces") or [])}

def wrapper(name):
    return f"{RUNDIR}/{name}.jsonc"

def bars_by_output(mons):
    """saida -> pid da instancia de waybar fixada nela (acha pelo config)."""
    res = {}
    try:
        out = subprocess.run(["pgrep", "-a", "-x", "waybar"],
                             capture_output=True, text=True).stdout
    except Exception:
        return res
    for line in out.splitlines():
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        pid, cmd = int(parts[0]), parts[1]
        for m in mons:
            if wrapper(m["name"]) in cmd:
                res[m["name"]] = pid
    return res

def ensure_bars(mons):
    """1 waybar por monitor conectado (idempotente). Mata barras orfas."""
    os.makedirs(RUNDIR, exist_ok=True)
    names = [m["name"] for m in mons]
    running = bars_by_output(mons)
    # mata barras de monitores que sumiram (hotplug-out)
    for name, pid in running.items():
        if name not in names:
            try: os.kill(pid, signal.SIGKILL)
            except Exception: pass
    # mata qualquer waybar "solta" (sem nosso wrapper) p/ evitar duplicata
    try:
        out = subprocess.run(["pgrep", "-a", "-x", "waybar"],
                             capture_output=True, text=True).stdout
        for line in out.splitlines():
            parts = line.split(None, 1)
            if len(parts) == 2 and RUNDIR not in parts[1]:
                try: os.kill(int(parts[0]), signal.SIGKILL)
                except Exception: pass
    except Exception:
        pass
    # lanca as que faltam
    running = bars_by_output(mons)
    launched = False
    for name in names:
        if name not in running:
            with open(wrapper(name), "w") as f:
                json.dump({"output": name, "include": [MAIN_CONFIG]}, f)
            subprocess.Popen(["waybar", "-c", wrapper(name), "-s", STYLE],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            launched = True
    if launched:
        time.sleep(0.6)

def rel_y(m, c):
    """y do cursor relativo ao topo do monitor m, ou None se nao estiver nele."""
    if not c:
        return None
    cx, cy = c.get("x"), c.get("y")
    scale = m.get("scale", 1) or 1
    lw, lh = m["width"] / scale, m["height"] / scale
    mx, my = m["x"], m["y"]
    if mx <= cx < mx + lw and my <= cy < my + lh:
        return cy - my
    return None

def is_visible(m):
    return m["reserved"][1] > 0

def reconcile():
    """ajusta a visibilidade de cada barra ao estado desejado. Retorna True
       se algum monitor esta em fullscreen (=> precisamos fazer polling)."""
    mons   = monitors()
    wsfs   = ws_fullscreen()
    pidmap = bars_by_output(mons)
    c      = cursor()
    any_fs = False
    toggled = False
    for m in mons:
        awid   = m.get("activeWorkspace", {}).get("id")
        mon_fs = wsfs.get(awid, False)
        if mon_fs:
            any_fs = True
            ry = rel_y(m, c)
            if ry is None:                 # cursor noutro monitor -> esconde
                desired = False
            elif ry <= REVEAL_AT:          # encostou no topo -> revela
                desired = True
            elif ry >= HIDE_BELOW:         # desceu -> esconde
                desired = False
            else:                          # zona morta -> mantem
                desired = is_visible(m)
        else:
            desired = True                 # sem fullscreen -> barra normal
        pid = pidmap.get(m["name"])
        if pid and is_visible(m) != desired:
            try:
                os.kill(pid, signal.SIGUSR1)
                toggled = True
            except Exception:
                pass
    if toggled:
        time.sleep(SETTLE)
    return any_fs

# eventos que podem mudar fullscreen / layout
WATCH    = ("fullscreen", "workspace", "focusedmon", "activewindowv2",
            "openwindow", "closewindow", "movewindow")
HOTPLUG  = ("monitoraddedv2", "monitoradded", "monitorremoved")

ensure_bars(monitors())
any_fs = reconcile()

s = socket.socket(socket.AF_UNIX)
s.connect(sockpath)
s.setblocking(False)
buf = b""
while True:
    timeout = POLL if any_fs else None   # so faz polling em fullscreen
    r, _, _ = select.select([s], [], [], timeout)
    if r:
        try:
            data = s.recv(8192)
        except BlockingIOError:
            data = b""
        if not data:
            break
        buf += data
        hotplug = changed = False
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            ev = line.decode(errors="ignore").split(">>", 1)[0]
            if ev in HOTPLUG:
                hotplug = True
            elif ev in WATCH:
                changed = True
        if hotplug:
            ensure_bars(monitors())
        if hotplug or changed:
            any_fs = reconcile()
    else:
        any_fs = reconcile()
PY
