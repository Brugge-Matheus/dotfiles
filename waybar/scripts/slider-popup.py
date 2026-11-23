#!/usr/bin/python3
"""slider-popup — popup com slider (brilho / volume) aberto pela waybar, no tema "Terminal Refinado".

  slider-popup.py brightness     clique no indicador de brilho
  slider-popup.py volume         clique DIREITO no indicador de som (esquerdo = mutar)
  slider-popup.py --get brightness|volume        valor atual em % (para testes/scripts)
  slider-popup.py --set brightness|volume N      aplica N%

O popup aparece logo abaixo da barra, perto do cursor, no monitor onde voce clicou. Fecha com Esc, clicando
no indicador de novo ou ao tirar o mouse de cima do painel. O volume vai de 0 a 200% (marca em 100%) — o scroll da waybar continua
sem limite (acima de 100% pode distorcer). Usa /usr/bin/python3 (precisa de python-gobject + gtk4-layer-shell;
o python3 do asdf nao tem 'gi').
"""
import json
import os
import signal
import subprocess
import sys

# gtk4-layer-shell precisa ser carregado ANTES do libwayland (senao "Failed to initialize layer surface"):
# reexecuta uma vez com LD_PRELOAD.
os.environ.setdefault("GSK_RENDERER", "cairo")   # renderizador GL leva ~2s p/ iniciar; cairo abre em ~0.2s
_LS = "/usr/lib/libgtk4-layer-shell.so"
if os.path.exists(_LS) and _LS not in os.environ.get("LD_PRELOAD", ""):
    os.environ["LD_PRELOAD"] = (_LS + ":" + os.environ.get("LD_PRELOAD", "")).rstrip(":")
    os.execv(sys.executable, [sys.executable] + sys.argv)

PIDFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "slider-popup.pid")
BAR_H = 32          # altura da waybar
GAP = 4             # folga entre a barra e o popup
PANEL_W = 300       # largura do popup
VOL_MAX = 200       # teto do slider de volume (%)


# ----------------------------------------------------------------------------- backends
def get_brightness():
    out = subprocess.run(["brightnessctl", "-m"], capture_output=True, text=True).stdout.strip()
    return int(out.split(",")[3].rstrip("%"))


def set_brightness(pct):
    pct = max(1, min(100, int(pct)))          # minimo 1%: nunca apaga a tela de vez
    subprocess.Popen(["brightnessctl", "-q", "set", f"{pct}%"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def get_volume():
    out = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True).stdout
    parts = out.split()
    return round(float(parts[1]) * 100), "[MUTED]" in out


def set_volume(pct):
    pct = max(0, min(VOL_MAX, int(pct)))
    # sem -l: nao limita em 100% (mesmo comportamento do scroll da waybar)
    subprocess.Popen(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{pct}%"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def toggle_mute():
    subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])


# ----------------------------------------------------------------------------- CLI auxiliar
def cli(argv):
    if argv[0] == "--get":
        print(get_brightness() if argv[1] == "brightness" else get_volume()[0])
    elif argv[0] == "--set":
        (set_brightness if argv[1] == "brightness" else set_volume)(argv[2])
        subprocess.run(["sleep", "0.3"])
    sys.exit(0)


if len(sys.argv) >= 3 and sys.argv[1] in ("--get", "--set"):
    cli(sys.argv[1:])
if len(sys.argv) != 2 or sys.argv[1] not in ("brightness", "volume"):
    sys.exit(__doc__)
KIND = sys.argv[1]

# clicar de novo no indicador (ou rodar de novo) fecha o popup aberto
try:
    old = int(open(PIDFILE).read())
    if old != os.getpid() and os.path.exists(f"/proc/{old}") and b"slider-popup" in open(f"/proc/{old}/cmdline", "rb").read():
        os.kill(old, signal.SIGTERM)
        sys.exit(0)
except (FileNotFoundError, ValueError, ProcessLookupError):
    pass
open(PIDFILE, "w").write(str(os.getpid()))

import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402
from gi.repository import Gtk4LayerShell as LS  # noqa: E402

CSS = b"""
window.backdrop, window { background: transparent; box-shadow: none; }
*:focus, *:focus-visible { outline: none; }
.panel { background: #0b0b0c; border: 1px solid #30303a; border-radius: 2px; padding: 12px 14px; }
.panel label { color: #e7e7e6; font-family: "JetBrainsMono Nerd Font", monospace; font-size: 13px; }
.title { color: #8a8a8f; }
.pct { color: #d6a84a; font-weight: 700; font-size: 15px; }
.hint { color: #55555a; font-size: 11px; }
scale trough { background: #22222a; min-height: 4px; border-radius: 2px; border: none; outline: none; box-shadow: none; }
scale trough:focus, scale:focus, scale:focus-within { outline: none; box-shadow: none; }
scale highlight { background: #d6a84a; border-radius: 2px; border: none; outline: none; box-shadow: none; }
scale slider { background: #e7e7e6; min-width: 14px; min-height: 14px; margin: 0; border-radius: 2px; border: none; box-shadow: none; }
scale slider:hover { background: #eac884; }
scale mark indicator { background: #55555a; min-width: 1px; min-height: 6px; }
scale marks label { color: #55555a; font-size: 10px; }
button { background: #16161a; color: #e7e7e6; border: 1px solid #22222a; border-radius: 2px; padding: 2px 10px; box-shadow: none; }
button:hover { background: #22222a; color: #eac884; }
button label { font-family: "JetBrainsMono Nerd Font", monospace; font-size: 12px; }
"""


def cursor_and_monitor():
    """(nome do monitor, x do cursor relativo ao monitor, x do monitor) via hyprctl."""
    try:
        cur = json.loads(subprocess.check_output(["hyprctl", "cursorpos", "-j"], timeout=2))
        mons = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], timeout=2))
    except Exception:
        return None, 200, 0
    for m in mons:
        w = int(m["width"] / (m.get("scale") or 1))
        if m["x"] <= cur["x"] < m["x"] + w:
            return m["name"], cur["x"] - m["x"], w
    return mons[0]["name"], 200, int(mons[0]["width"])


class Popup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id=None, flags=0x20)  # NON_UNIQUE
        self.pending = None
        self.timer = None
        self.updating = False

    def do_activate(self):
        css = Gtk.CssProvider()
        css.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        win = Gtk.ApplicationWindow(application=self)
        win.add_css_class("backdrop")
        LS.init_for_window(win)
        LS.set_namespace(win, "slider-popup")
        LS.set_layer(win, LS.Layer.OVERLAY)
        LS.set_anchor(win, LS.Edge.TOP, True)       # janela PEQUENA colada na barra (nada de tela cheia)
        LS.set_anchor(win, LS.Edge.LEFT, True)
        LS.set_keyboard_mode(win, LS.KeyboardMode.EXCLUSIVE)   # Esc fecha

        name, cx, mon_w = cursor_and_monitor()
        if name:
            for gm in Gdk.Display.get_default().get_monitors():
                if gm.get_connector() == name:
                    LS.set_monitor(win, gm)
        LS.set_margin(win, LS.Edge.TOP, GAP)   # o layer-shell ja desconta os 32px que a waybar reserva
        LS.set_margin(win, LS.Edge.LEFT, max(4, min(cx - PANEL_W // 2, mon_w - PANEL_W - 4)))

        # painel do slider
        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        panel.add_css_class("panel")
        panel.set_size_request(PANEL_W, -1)
        self.panel = panel

        head = Gtk.Box(spacing=8)
        self.title = Gtk.Label(label="", xalign=0, hexpand=True)
        self.title.add_css_class("title")
        self.pct = Gtk.Label(label="")
        self.pct.add_css_class("pct")
        head.append(self.title)
        head.append(self.pct)
        panel.append(head)

        if KIND == "brightness":
            lo, hi, cur, muted = 1, 100, get_brightness(), False
        else:
            lo, hi = 0, VOL_MAX
            cur, muted = get_volume()
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, lo, hi, 1)
        self.scale.set_draw_value(False)
        self.scale.set_hexpand(True)
        if KIND == "volume":
            self.scale.add_mark(100, Gtk.PositionType.BOTTOM, "100%")
        self.updating = True
        self.scale.set_value(min(max(cur, lo), hi))
        self.updating = False
        self.scale.connect("value-changed", self.on_change)
        panel.append(self.scale)

        if KIND == "volume":
            row = Gtk.Box(spacing=8)
            self.mute_btn = Gtk.Button(label="")
            self.mute_btn.connect("clicked", self.on_mute)
            mixer = Gtk.Button(label="  Mixer")
            mixer.connect("clicked", lambda *_: (subprocess.Popen(["pavucontrol"]), self.quit()))
            row.append(self.mute_btn)
            row.append(mixer)
            panel.append(row)
        self.refresh_labels(cur, muted)

        win.set_child(panel)
        # fecha sozinho quando o mouse sai do painel (700ms) ou se ele nunca entrar nele (4s)
        motion = Gtk.EventControllerMotion()
        motion.connect("enter", lambda *_: self.cancel_close())
        motion.connect("leave", lambda *_: self.arm_close(700))
        panel.add_controller(motion)
        self.close_timer = None
        self.arm_close(4000)

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", lambda c, kv, kc, st: (self.quit(), True)[1] if kv == Gdk.KEY_Escape else False)
        win.add_controller(keys)
        win.present()
        try:
            from gi.repository import GLibUnix
            GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, lambda: (self.quit(), False)[1])
        except ImportError:
            GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, lambda: (self.quit(), False)[1])
        # se o volume/brilho mudar por fora (teclas, scroll da barra), o slider acompanha
        GLib.timeout_add(400, self.sync_external)

    # ------------------------------------------------------------------ eventos
    def arm_close(self, ms):
        self.cancel_close()
        self.close_timer = GLib.timeout_add(ms, lambda: (self.quit(), False)[1])

    def cancel_close(self):
        if self.close_timer is not None:
            GLib.source_remove(self.close_timer)
            self.close_timer = None

    def on_change(self, scale):
        if self.updating:
            return
        self.pending = int(round(scale.get_value()))
        self.refresh_labels(self.pending, False)
        if self.timer is None:       # limita a ~20 chamadas/s ao arrastar
            self.timer = GLib.timeout_add(50, self.flush)

    def flush(self):
        self.timer = None
        if self.pending is None:
            return False
        if KIND == "brightness":
            set_brightness(self.pending)
        else:
            if get_volume()[1]:      # arrastar o volume tira do mudo
                subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"])
            set_volume(self.pending)
        self.pending = None
        return False

    def on_mute(self, *_):
        toggle_mute()
        v, m = get_volume()
        self.refresh_labels(v, m)

    def sync_external(self):
        if self.pending is not None or self.timer is not None:
            return True
        cur, muted = (get_brightness(), False) if KIND == "brightness" else get_volume()
        if abs(cur - self.scale.get_value()) >= 1 and cur <= self.scale.get_adjustment().get_upper():
            self.updating = True
            self.scale.set_value(cur)
            self.updating = False
        self.refresh_labels(cur, muted)
        return True

    def refresh_labels(self, val, muted):
        if KIND == "brightness":
            self.title.set_text(chr(0xF185) + "  Brilho")
            self.pct.set_text(f"{val}%")
        else:
            self.title.set_text((chr(0xF026) if muted else chr(0xF028)) + "  Volume" + ("  (mudo)" if muted else ""))
            self.pct.set_text(f"{val}%")
            self.mute_btn.set_label((chr(0xF028) + "  Ativar som") if muted else (chr(0xF026) + "  Mutar"))


if __name__ == "__main__":
    try:
        Popup().run(None)
    finally:
        try:
            os.remove(PIDFILE)
        except OSError:
            pass
