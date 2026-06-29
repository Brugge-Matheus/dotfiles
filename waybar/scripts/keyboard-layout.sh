#!/usr/bin/env bash
# Sub-menu (fuzzel) p/ trocar o layout do teclado em runtime.
# Os layouts vem do hyprland.lua (input.kb_layout = "us,br" / kb_variant="intl,abnt2"):
#   indice 0 = US Internacional   |   indice 1 = PT-BR ABNT2
# A troca e por sessao (volta ao padrao US intl quando o Hyprland reinicia).
set -euo pipefail

CFG="$HOME/.config/fuzzel/powermenu.ini"

# layout ativo agora (do teclado principal) -> marca o item atual
cur="$(hyprctl devices -j 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
ks=[k for k in d.get('keyboards',[]) if k.get('main')]
print(ks[0].get('active_keymap','') if ks else '')
" 2>/dev/null || true)"

dot_us=" "; dot_br=" "
case "$cur" in
  *US*|*us*|*English*) dot_us="" ;;
  *Brazil*|*Portug*)   dot_br="" ;;
esac

menu="$(printf '  US Internacional %s\n  PT-BR ABNT2 %s' "$dot_us" "$dot_br")"

chosen="$(printf '%s' "$menu" | fuzzel --dmenu --config "$CFG" \
  --anchor center --width 28 --lines 3 --prompt 'Teclado> ')" || exit 0
[ -z "$chosen" ] && exit 0

case "$chosen" in
  *US*|*Internacional*) hyprctl switchxkblayout all 0 >/dev/null && notify-send -t 1500 "Teclado" "US Internacional" ;;
  *ABNT*|*PT-BR*)       hyprctl switchxkblayout all 1 >/dev/null && notify-send -t 1500 "Teclado" "PT-BR ABNT2" ;;
esac
