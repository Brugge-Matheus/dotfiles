#!/usr/bin/env bash
# Widget de status do Spotify para a Waybar (return-type: json).
# Os glifos sao gerados pelo python via chr(codepoint) -> fonte 100% ASCII.
player=spotify

status=$(playerctl -p "$player" status 2>/dev/null)
title=$(playerctl -p "$player" metadata title 2>/dev/null)
artist=$(playerctl -p "$player" metadata artist 2>/dev/null)
running=$(playerctl -p "$player" status >/dev/null 2>&1 && echo 1 || echo 0)

python3 - "$running" "$status" "$title" "$artist" <<'PY'
import json, sys
running, status, title, artist = (sys.argv + [""] * 4)[1:5]
ICON = chr(0xF1BC)  # logo spotify
if running != "1":
    print(json.dumps({"text": f"{ICON} Spotify", "class": "closed",
                      "tooltip": "Spotify fechado (clique para abrir)"}))
    raise SystemExit
state = chr(0xF04B) if status == "Playing" else chr(0xF04C)  # play / pause
parts = [p for p in (title, artist) if p]
song = " - ".join(parts) if parts else "-"
print(json.dumps({"text": f"{ICON} {state} {song}",
                  "class": "playing" if status == "Playing" else "paused",
                  "tooltip": f"{title}\n{artist}".strip()}))
PY
