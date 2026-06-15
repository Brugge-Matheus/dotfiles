#!/usr/bin/env bash
# Waybar auto-hide em FULLSCREEN, com revelar-ao-hover no topo.
#
# Comportamento:
#   - Sem janela em fullscreen: a Waybar fica normal (visivel, reserva 32px).
#   - Com fullscreen no workspace ativo: a Waybar some. Encostar o mouse no
#     TOPO do monitor a revela (overlay sobre a janela); descer o mouse a
#     esconde de novo.
#
# A visibilidade da Waybar e alternada via SIGUSR1 (toggle). Como toggle e
# fragil (um sinal perdido inverteria tudo), NAO confiamos num estado interno:
# antes de cada acao lemos o estado REAL (a reserva do monitor focado) e so
# disparamos o sinal se precisar mudar -> auto-corrige sozinho.
#
# Escuta os eventos do Hyprland (socket2) p/ saber quando ha fullscreen e so
# faz polling do cursor enquanto estiver em fullscreen (zero custo fora dele).
# Iniciado no autostart do Hyprland.
exec python3 <<'PY'
import socket, os, json, subprocess, select, time

his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
rt  = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
sockpath = f"{rt}/hypr/{his}/.socket2.sock"

REVEAL_AT  = 2     # cursor a <= 2px do topo -> revela
HIDE_BELOW = 40    # cursor a >= 40px do topo -> esconde (histerese > altura da barra)
POLL       = 0.10  # intervalo de polling do cursor (so em fullscreen)
SETTLE     = 0.30  # apos um toggle, espera propagar antes da proxima decisao

def hctl(*args):
    try:
        out = subprocess.run(["hyprctl", *args, "-j"],
                             capture_output=True, text=True).stdout
        return json.loads(out)
    except Exception:
        return None

def has_fullscreen():
    d = hctl("activeworkspace")
    return bool(d and d.get("hasfullscreen"))

def is_visible():
    """estado REAL da waybar: reserva de topo no monitor focado > 0."""
    for m in (hctl("monitors") or []):
        if m.get("focused"):
            return m["reserved"][1] > 0
    return True

def want(visible):
    """garante a visibilidade desejada lendo o estado real (idempotente)."""
    if is_visible() != visible:
        subprocess.run(["pkill", "-USR1", "-x", "waybar"])  # toggle
        time.sleep(SETTLE)   # deixa o estado propagar p/ nao re-disparar

def cursor_rel_y():
    """y do cursor relativo ao topo do monitor onde ele esta (ou None)."""
    c = hctl("cursorpos")
    if not c:
        return None
    cx, cy = c.get("x"), c.get("y")
    for m in (hctl("monitors") or []):
        scale = m.get("scale", 1) or 1
        lw, lh = m["width"] / scale, m["height"] / scale
        mx, my = m["x"], m["y"]
        if mx <= cx < mx + lw and my <= cy < my + lh:
            return cy - my
    return None

# eventos que podem mudar o estado de fullscreen do workspace ativo
WATCH = ("fullscreen", "workspace", "focusedmon", "activewindowv2",
         "openwindow", "closewindow", "movewindow",
         "monitoraddedv2", "monitorremoved")

s = socket.socket(socket.AF_UNIX)
s.connect(sockpath)
s.setblocking(False)

fs = has_fullscreen()
want(not fs)
buf = b""
while True:
    # so faz polling do cursor enquanto ha fullscreen; senao bloqueia no socket
    timeout = POLL if fs else None
    r, _, _ = select.select([s], [], [], timeout)
    if r:
        try:
            data = s.recv(8192)
        except BlockingIOError:
            data = b""
        if not data:
            break
        buf += data
        changed = False
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            ev = line.decode(errors="ignore").split(">>", 1)[0]
            if ev in WATCH:
                changed = True
        if changed:
            new_fs = has_fullscreen()
            if new_fs != fs:
                fs = new_fs
                want(not fs)   # entrou -> esconde; saiu -> mostra
    elif fs:
        # timeout em fullscreen: revela/esconde conforme o cursor no topo
        ry = cursor_rel_y()
        if ry is not None:
            if ry <= REVEAL_AT:
                want(True)
            elif ry >= HIDE_BELOW:
                want(False)
PY
