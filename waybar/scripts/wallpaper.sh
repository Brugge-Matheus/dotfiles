#!/usr/bin/env bash
# Trocador de wallpaper: escolhe o ALVO (ambos os monitores ou um especifico)
# e a imagem de ~/Pictures/Wallpapers, aplicando via awww (swww).
#   sem arg        -> menu (alvo + imagem)
#   random         -> imagem aleatoria em todos os monitores
set -euo pipefail

dir="$HOME/Pictures/Wallpapers"
mkdir -p "$dir"
CFG="$HOME/.config/fuzzel/powermenu.ini"

pgrep -x awww-daemon >/dev/null || { awww-daemon & sleep 0.5; }

apply() {  # $1=imagem  $2=outputs (vazio = todos)
  local img="$1" out="${2:-}"
  if [ -n "$out" ]; then
    awww img --outputs "$out" "$img" --transition-type any --transition-fps 60 --transition-duration 1
  else
    awww img "$img" --transition-type any --transition-fps 60 --transition-duration 1
  fi
}

mapfile -t imgs < <(find "$dir" -maxdepth 1 -type f \
  \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)
if [ "${#imgs[@]}" -eq 0 ]; then
  notify-send "Wallpaper" "Nenhuma imagem em $dir"
  exit 0
fi

# modo aleatorio (todos os monitores)
if [ "${1:-}" = "random" ]; then
  apply "${imgs[RANDOM % ${#imgs[@]}]}" ""
  exit 0
fi

# toggle: fecha se ja aberto
if pgrep -x fuzzel >/dev/null; then pkill -x fuzzel; exit 0; fi

# 1) ALVO — "Ambos" + cada monitor conectado
target_menu="$(hyprctl monitors -j 2>/dev/null | python3 -c "
import json,sys
mons=json.load(sys.stdin)
print('Ambos os monitores')
for m in mons:
    desc=m.get('description','')[:28]
    print(f\"{m['name']}  ({desc})\")
")"
target="$(printf '%s' "$target_menu" | fuzzel --dmenu --config "$CFG" --anchor center --width 36 --lines 6)" || exit 0
[ -z "$target" ] && exit 0

# converte a escolha em lista de outputs ('' = todos)
if [ "$target" = "Ambos os monitores" ]; then
  outputs=""
else
  outputs="${target%% *}"   # primeiro token = nome do monitor
fi

# 2) IMAGEM
chosen="$(printf '%s\n' "${imgs[@]}" | xargs -n1 basename | fuzzel --dmenu \
  --config "$CFG" --anchor center --width 40 --lines 10)" || exit 0
[ -z "$chosen" ] && exit 0

apply "$dir/$chosen" "$outputs"
notify-send -t 1500 "Wallpaper" "Aplicado em: ${target}"
