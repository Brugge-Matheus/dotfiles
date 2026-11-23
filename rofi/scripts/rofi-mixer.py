#!/usr/bin/env python3
# =====================================================================
#  rofi-mixer.py — "Mixer de volume" (SUPER + M): volume POR PROGRAMA, como o mixer do Windows.
#  Modo "script" do rofi. Lista o volume geral da saida + cada app que esta tocando som
#  (varias streams do mesmo app, ex.: abas do navegador, viram UMA linha e sao ajustadas juntas).
#
#  TECLAS
#    Seta Direita / Esquerda      volume +5% / -5% da linha selecionada (a lista continua aberta)
#    Enter                        silencia / reativa a linha selecionada
#    Esc                          fecha
#  Maximo 150% (acima de 100% distorce; e o mesmo limite do pavucontrol). Apps que ainda nao tocaram nada
#  nao aparecem (o PipeWire so conhece o app enquanto ele tem uma stream de audio aberta).
#
#  Usa pactl (pipewire-pulse). Protocolo do modo script: ROFI_RETV 0 = abrir, 1 = Enter na linha (ROFI_INFO = id),
#  12 = kb-custom-3 (+5), 13 = kb-custom-4 (-5) — as teclas custom vem do rofi-ext.sh mixer
#  (janela propria: num modo do launcher as setas quebrariam as outras abas).
# =====================================================================
import json, os, subprocess, sys

STEP, MAXV = 5, 150
ICON = ""   # volume-up (Nerd Font), rotulo da aba
BAR = 20

def pactl(*a):
    return subprocess.run(["pactl", *a], capture_output=True, text=True).stdout

def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def pct(vol):   # media dos canais, em %
    vals = [int(v["value_percent"].rstrip("%")) for v in vol.values()]
    return round(sum(vals) / len(vals)) if vals else 0

def load():
    """-> lista de dicts: id, label, vol, mute, kind ('sink'|'app'), targets=[ids]"""
    rows = []
    sink = pactl("get-default-sink").strip()
    for s in json.loads(pactl("-f", "json", "list", "sinks") or "[]"):
        if s["name"] == sink:
            rows.append(dict(id="sink", label="Volume geral", vol=pct(s["volume"]), mute=s["mute"],
                             kind="sink", targets=[s["index"]]))
    apps = {}
    for i in json.loads(pactl("-f", "json", "list", "sink-inputs") or "[]"):
        p = i.get("properties", {})
        name = p.get("application.name") or p.get("node.name") or "?"
        a = apps.setdefault(name, dict(id="app:" + name, label=name, vols=[], mute=True, kind="app", targets=[]))
        a["vols"].append(pct(i["volume"]))
        a["mute"] = a["mute"] and i["mute"]
        a["targets"].append(i["index"])
    for a in sorted(apps.values(), key=lambda x: x["label"].lower()):
        a["vol"] = round(sum(a.pop("vols")) / len(a["targets"]))
        rows.append(a)
    return rows

def apply(row, new=None, toggle=False):
    sub = "sink" if row["kind"] == "sink" else "sink-input"
    for t in row["targets"]:
        if new is not None:
            pactl(f"set-{sub}-volume", str(t), f"{new}%")
        if toggle:
            pactl(f"set-{sub}-mute", str(t), "toggle" if row["kind"] == "sink" else ("0" if row["mute"] else "1"))

def show(rows, sel_id=None, msg=None):
    print("\0markup-rows\x1ftrue")
    print("\0use-hot-keys\x1ftrue")   # sem isto o rofi ignora kb-custom-N em modos script   # sem isto o rofi ignora kb-custom-N em modos script
    print(f"\0prompt\x1f{ICON}")
    print("\0message\x1f" + (msg or "← → ajusta o volume ±5% · ↑ ↓ escolhe o programa · Enter silencia · Esc fecha"))
    idx = next((n for n, r in enumerate(rows) if r["id"] == sel_id), 0)
    print("\0keep-selection\x1ftrue")
    print(f"\0new-selection\x1f{idx}")   # a linha mexida continua selecionada apos o redesenho
    if not any(r["kind"] == "app" for r in rows):
        msg2 = "  nenhum programa tocando som agora (abra o áudio/vídeo e volte aqui)"
        print(f"<span foreground='#55555a'>{esc(msg2)}</span>\0info\x1fnone")
    for r in rows:
        n = min(r["vol"], MAXV)
        filled = round(BAR * n / 100) if n <= 100 else BAR
        col = "#55555a" if r["mute"] else ("#e6b450" if r["vol"] > 100 else "#7fd962")
        bar = "█" * filled + "░" * (BAR - filled)
        icon = "" if r["mute"] else ("" if r["kind"] == "sink" else "")
        state = "mudo" if r["mute"] else f"{r['vol']}%"
        print(f"{icon}  {esc(r['label']):<22} <span foreground='{col}'>{bar}</span>  {state}\0info\x1f{r['id']}")

def main():
    retv = int(os.environ.get("ROFI_RETV", "0"))
    info = os.environ.get("ROFI_INFO", "")
    rows = load()
    row = next((r for r in rows if r["id"] == info), None)
    msg = None
    if row and retv in (1, 12, 13):
        if retv == 1:
            apply(row, toggle=True)
        else:
            new = max(0, min(MAXV, row["vol"] + (STEP if retv == 12 else -STEP)))
            apply(row, new=new)
            # mexer no volume de uma linha muda reativa o som dela
            if row["mute"] and retv == 12:
                apply(row, toggle=True)
        rows = load()
    show(rows, info or None, msg)

main()
