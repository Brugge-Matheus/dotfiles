#!/usr/bin/env bash
# Historico de clipboard: cliphist + fuzzel. Escolhido -> volta pro clipboard.
set -euo pipefail

if pgrep -x fuzzel >/dev/null; then pkill -x fuzzel; exit 0; fi

if ! command -v cliphist >/dev/null 2>&1; then
  notify-send "Clipboard" "cliphist nao instalado. Rode: sudo pacman -S cliphist"
  exit 0
fi

sel="$(cliphist list | fuzzel --dmenu \
  --config "$HOME/.config/fuzzel/powermenu.ini" \
  --anchor center --width 60 --lines 12)" || exit 0

[ -n "$sel" ] && printf '%s' "$sel" | cliphist decode | wl-copy
