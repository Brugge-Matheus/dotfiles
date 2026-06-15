#!/usr/bin/env bash
# Abre ou foca o Spotify (clique no widget da Waybar).
# Acha a janela do Spotify e foca por ENDERECO (robusto). Nesta versao do
# Hyprland (config Lua), "hyprctl dispatch focuswindow ..." NAO funciona; a
# forma correta via CLI e hl.dsp.focus({ window = "address:0x..." }).
addr="$(hyprctl clients -j 2>/dev/null | python3 -c '
import sys, json
try:
    clients = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for c in clients:
    if "spotify" in (c.get("class") or "").lower():
        print(c["address"]); break
' 2>/dev/null)"

if [ -n "$addr" ]; then
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null 2>&1
elif command -v spotify >/dev/null 2>&1; then
  setsid -f spotify >/dev/null 2>&1
elif command -v spotify-launcher >/dev/null 2>&1; then
  setsid -f spotify-launcher >/dev/null 2>&1
else
  notify-send "Spotify" "Nao instalado. Instale com: yay -S spotify"
fi
