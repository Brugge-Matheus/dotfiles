#!/usr/bin/env bash
# Helper: le opcoes do stdin e abre o fuzzel como dropdown CENTRADO logo abaixo
# do ponto onde o cursor esta. Auto-dimensiona (linhas e largura conforme o
# conteudo). Fecha com Esc / ao escolher / clicando no mesmo botao. Escolha -> stdout.
set -euo pipefail

CFG="$HOME/.config/fuzzel/powermenu.ini"
BAR_OFFSET=4

# le todas as opcoes (precisamos contar linhas/medir largura antes de abrir)
input="$(cat)"
nlines="$(printf '%s\n' "$input" | grep -c .)"
maxlen="$(printf '%s\n' "$input" | awk '{ if (length>m) m=length } END{ print m+0 }')"
width=$(( maxlen + 4 ))                 # folga lateral p/ a bolinha nao truncar
menu_w=$(( width * 9 + 40 ))            # largura aprox. em px (p/ centralizar)

read -r cx cy < <(hyprctl cursorpos 2>/dev/null | tr -d ',')

pos="$(CX="${cx:-0}" MW="$menu_w" MONS="$(hyprctl monitors -j 2>/dev/null)" python3 <<'PY'
import json, os
cx = int(os.environ.get("CX", "0"))
mw = int(os.environ.get("MW", "150"))
try:    mons = json.loads(os.environ.get("MONS", "[]"))
except Exception: mons = []
if not mons:
    print("'' 0"); raise SystemExit
m = mons[0]
for mon in mons:
    x, w = mon["x"], int(mon["width"]/mon["scale"])
    if x <= cx < x + w:
        m = mon; break
x, w = m["x"], int(m["width"]/m["scale"])
left = max(0, min((cx - x) - mw // 2, w - mw))   # centraliza no cursor
print(f"{m['name']} {left}")
PY
)"
out="${pos% *}"; lx="${pos##* }"

args=(--dmenu --config "$CFG" --anchor top-left --x-margin "$lx" --y-margin "$BAR_OFFSET"
      --lines "$nlines" --width "$width")
[ -n "$out" ] && args+=(--output "$out")

printf '%s' "$input" | fuzzel "${args[@]}"
