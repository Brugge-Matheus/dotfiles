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
# Auto-cura: depois de suspend/resume o monitor externo pode ser religado (novo
# modeset) e o processo da waybar sobrevive SEM surface (barra some, processo
# vivo). Por isso verificamos a layer-surface real (hyprctl layers) e relancamos
# a instancia daquele monitor se ela nao tiver barra desenhada.
# Iniciado no autostart do Hyprland (substitui o "waybar" direto).
export WF_SELF="$(readlink -f "$0")"   # usado pelo watchdog p/ se reexecutar
exec python3 <<'PY'
import socket, os, json, subprocess, select, time, signal, sys, faulthandler

HOME = os.environ["HOME"]
rt   = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
his  = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")

def _find_sock(sig):
    """socket de eventos do Hyprland; se a variavel faltar/estiver velha (rodando como servico), usa a instancia mais nova"""
    p = f"{rt}/hypr/{sig}/.socket2.sock"
    if sig and os.path.exists(p):
        return p, sig
    cands = [d for d in os.listdir(f"{rt}/hypr") if os.path.exists(f"{rt}/hypr/{d}/.socket2.sock")] if os.path.isdir(f"{rt}/hypr") else []
    if not cands:
        sys.exit("waybar-fullscreen: nenhuma instancia do Hyprland encontrada")
    cands.sort(key=lambda d: os.path.getmtime(f"{rt}/hypr/{d}/.socket2.sock"))
    return f"{rt}/hypr/{cands[-1]}/.socket2.sock", cands[-1]

sockpath, his = _find_sock(his)
os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = his   # hyprctl filho usa a mesma instancia

# --- Protecao EXTERNA (systemd): heartbeat WATCHDOG=1 a cada volta do laco. Se o laco parar (travado em
# qualquer chamada, inclusive as que ignoram sinais), o systemd mata e reinicia o servico. Fora do systemd
# (NOTIFY_SOCKET ausente) vira no-op.
def sd_notify(msg):
    addr = os.environ.get("NOTIFY_SOCKET")
    if not addr:
        return
    try:
        if addr[0] == "@":
            addr = "\0" + addr[1:]
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as n:
            n.connect(addr)
            n.send(msg.encode())
    except Exception:
        pass

# Diagnostico: se o laco ficar parado >15s, imprime no stderr (journal) ONDE esta travado.
faulthandler.enable(file=sys.stderr)

RUNDIR      = f"{rt}/waybar"
MAIN_CONFIG = f"{HOME}/.config/waybar/config.jsonc"
STYLE       = f"{HOME}/.config/waybar/style.css"

REVEAL_AT  = 2     # cursor a <= 2px do topo do monitor -> revela a barra dele
HIDE_BELOW = 40    # cursor a >= 40px do topo -> esconde (histerese > altura da barra)
POLL       = 0.10  # polling do cursor enquanto algum monitor estiver em fullscreen
SETTLE     = 0.25  # apos um toggle, espera propagar antes da proxima leitura
HEALTH_EVERY = 3.0 # checagem periodica das barras (mesmo sem eventos)
BAR_GRACE    = 4.0 # tempo p/ uma barra recem-lancada criar a surface antes de ser julgada
WATCHDOG     = int(os.environ.get("WF_WATCHDOG", "20"))  # s sem o laco principal rodar => daemon travado

# Auto-cura do PROPRIO daemon: ja vimos o processo ficar vivo porem parado (sem acordar
# nem reagir a fullscreen) por horas. O laco principal re-arma este alarme a cada volta;
# se ele parar de rodar (travado em qualquer chamada bloqueante), o SIGALRM dispara e o
# script se reexecuta do zero (mesmo PID; as waybars em andamento sao reaproveitadas).
def _wedged(signum, frame):
    self_path = os.environ.get("WF_SELF")
    if self_path:
        os.execv("/usr/bin/env", ["env", "bash", self_path])
    os._exit(1)
signal.signal(signal.SIGALRM, _wedged)
signal.alarm(WATCHDOG)

# --- Menus abertos a partir da barra (botao direito num app da bandeja, slider, menu fuzzel...) -------------
# Em fullscreen a barra some quando o cursor desce de 40px, e o menu aberto some junto (e o pai dele). Entao a barra
# fica FIXA (pinned) enquanto houver um menu aberto. Dois sinais:
#   1. layer-surface de menu na tela (fuzzel, rofi, slider-popup, central de notificacoes...): visivel em `hyprctl layers`.
#   2. menu "popup" da bandeja (GTK): NAO aparece em layers/clients. Aqui usamos os cliques: binds nao-consumidores do
#      Hyprland (hypr/hyprland.lua) tocam $RUNDIR/click a cada clique de mouse e $RUNDIR/esc a cada Esc. Clique na
#      barra = fixa; clique fora da barra (ou noutro monitor) ou Esc = solta. Clique na barra com ela ja fixa mantem.
CLICK_FILE = f"{rt}/waybar/click"
ESC_FILE   = f"{rt}/waybar/esc"
MENU_LAYERS = {"fuzzel", "launcher", "rofi", "walker", "slider-popup", "swaync-control-center", "wlogout"}
pinned = {}        # saida -> True enquanto um menu aberto pela barra deve mante-la visivel

def _mtime(path):
    try:    return os.stat(path).st_mtime_ns
    except OSError: return 0
_seen = {"click": _mtime(CLICK_FILE), "esc": _mtime(ESC_FILE)}

def menu_layers():
    """saidas que tem agora uma layer de menu aberta"""
    res = set()
    d = hctl("layers") or {}
    for out, v in d.items():
        for ls in (v.get("levels") or {}).values():
            for l in ls:
                if l.get("namespace") in MENU_LAYERS:
                    res.add(out)
    return res

def poll_inputs(mons, c, fs_by_mon):
    """consome cliques/Esc novos e atualiza `pinned`"""
    clk, esc = _mtime(CLICK_FILE), _mtime(ESC_FILE)
    if esc != _seen["esc"]:
        _seen["esc"] = esc
        pinned.clear()
    if clk != _seen["click"]:
        _seen["click"] = clk
        for m in mons:
            ry = rel_y(m, c)
            name = m["name"]
            if ry is not None and fs_by_mon.get(name) and ry < HIDE_BELOW:
                pinned[name] = True        # clicou na barra: o que abrir (menu) fica protegido
            else:
                pinned.pop(name, None)     # clicou fora da barra / noutro monitor: menu fechou

def hctl(*args):
    try:
        out = subprocess.run(["hyprctl", *args, "-j"],
                             capture_output=True, text=True, timeout=3).stdout
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
                             capture_output=True, text=True, timeout=3).stdout
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

launched_at = {}   # saida -> instante do ultimo lancamento

def bar_surfaces():
    """saida -> conjunto de pids de waybar com layer-surface realmente criada."""
    res = {}
    d = hctl("layers") or {}
    for out, v in d.items():
        for ls in (v.get("levels") or {}).values():
            for l in ls:
                if l.get("namespace") == "waybar":
                    res.setdefault(out, set()).add(l.get("pid"))
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
                             capture_output=True, text=True, timeout=3).stdout
        for line in out.splitlines():
            parts = line.split(None, 1)
            if len(parts) == 2 and RUNDIR not in parts[1]:
                try: os.kill(int(parts[0]), signal.SIGKILL)
                except Exception: pass
    except Exception:
        pass
    # mata barras vivas mas SEM surface (pos suspend/resume), passada a carencia
    running = bars_by_output(mons)
    surf = bar_surfaces()
    now = time.time()
    for name, pid in list(running.items()):
        if pid in surf.get(name, ()):
            continue
        if now - launched_at.get(name, 0) < BAR_GRACE:
            continue
        try: os.kill(pid, signal.SIGKILL)
        except Exception: pass
        del running[name]
        time.sleep(0.2)
    # lanca as que faltam
    launched = False
    for name in names:
        if name not in running:
            launched_at[name] = time.time()
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
    fs_by_mon = {m["name"]: wsfs.get(m.get("activeWorkspace", {}).get("id"), False) for m in mons}
    for name in list(pinned):              # sem fullscreen nao ha o que proteger
        if not fs_by_mon.get(name):
            del pinned[name]
    poll_inputs(mons, c, fs_by_mon)
    menus = menu_layers() if any(fs_by_mon.values()) else set()
    for m in mons:
        awid   = m.get("activeWorkspace", {}).get("id")
        mon_fs = wsfs.get(awid, False)
        if mon_fs:
            any_fs = True
            ry = rel_y(m, c)
            if pinned.get(m["name"]) or m["name"] in menus:   # menu aberto pela barra -> mantem visivel
                desired = True
            elif ry is None:               # cursor noutro monitor -> esconde
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
last_health = time.time()
sd_notify("READY=1")
while True:
    signal.alarm(WATCHDOG)                       # laco vivo: re-arma o watchdog
    sd_notify("WATCHDOG=1")                      # heartbeat p/ o systemd (watchdog externo)
    faulthandler.dump_traceback_later(15, repeat=False, file=sys.stderr)   # re-arma o dump de diagnostico
    timeout = POLL if any_fs else HEALTH_EVERY   # polling rapido so em fullscreen; senao so health check
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
        if time.time() - last_health >= HEALTH_EVERY:
            ensure_bars(monitors())
            last_health = time.time()
        any_fs = reconcile()
PY
