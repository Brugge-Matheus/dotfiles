#!/usr/bin/env bash
# pip.sh — modo "picture-in-picture" para QUALQUER janela (video, terminal, logs, chamada...).
#
#   pip.sh toggle        ativa/desativa: a janela ativa vira flutuante, pequena e vai para o canto, FICANDO na
#                        workspace dela; ao desativar volta ao tiling (e desafixa, se estiver fixada).
#   pip.sh pin           fixa/solta a janela flutuante em TODAS as workspaces (por cima)
#   pip.sh corner tl|tr|bl|br   encaixa no canto (superior/inferior + esquerdo/direito) do monitor da janela
#   pip.sh next          proximo canto (horario: tr -> br -> bl -> tl)
#   pip.sh nudge dx dy   desloca em pixels (livre, p/ ajuste fino pelo teclado)
#   pip.sh size +|-      aumenta/diminui ~15% mantendo a proporcao e o canto
#
# Posicao livre com o mouse: SUPER + botao esquerdo arrastando (ja configurado no hyprland.lua).
# Estado (canto/tamanho) fica em $XDG_RUNTIME_DIR/pip/<endereco-da-janela>. Teclas: ver arch/KEYBINDS.md.
set -u
STATE="${XDG_RUNTIME_DIR:-/tmp}/pip"
MARGIN=20          # px de folga das bordas / da waybar
FRAC_W=28          # largura inicial = 28% do monitor (16:9)
mkdir -p "$STATE"
# limpa estado de janelas que ja foram fechadas
LIVE=$(hyprctl clients -j 2>/dev/null | grep -o '"address": "[^"]*"' | cut -d'"' -f4)
for f in "$STATE"/*; do [ -e "$f" ] && ! grep -qx "$(basename "$f")" <<<"$LIVE" && rm -f "$f"; done

win_json() { hyprctl activewindow -j 2>/dev/null; }
dsp() { hyprctl dispatch "$1" >/dev/null 2>&1; }

J=$(win_json)
[ -z "$J" ] || [ "$J" = "{}" ] && exit 0
# python le o JSON da janela ativa + monitores e imprime: addr floating pinned x y w h mx my mw mh (area util)
read -r ADDR FLOAT PINNED X Y W H MX MY MW MH < <(
  printf '%s' "$J" | python3 -c '
import json, subprocess, sys
w = json.load(sys.stdin)
mons = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"]))
m = next((m for m in mons if m["id"] == w["monitor"]), mons[0])
rl, rt, rr, rb = m["reserved"]            # waybar etc.
sc = m.get("scale", 1) or 1
mw, mh = int(m["width"] / sc), int(m["height"] / sc)
print(w["address"], int(w["floating"]), int(w["pinned"]), *w["at"], *w["size"],
      m["x"] + rl, m["y"] + rt, mw - rl - rr, mh - rt - rb)')
[ -n "${ADDR:-}" ] || exit 0
F="$STATE/$ADDR"

# --- helpers de geometria ----------------------------------------------------------------------
place() { # place <corner> <w> <h>  -> redimensiona e encaixa no canto (area util do monitor)
  local c=$1 w=$2 h=$3 x y
  case $c in
    tl|bl) x=$((MX + MARGIN)) ;;
    *)     x=$((MX + MW - w - MARGIN)) ;;
  esac
  case $c in
    tl|tr) y=$((MY + MARGIN)) ;;
    *)     y=$((MY + MH - h - MARGIN)) ;;
  esac
  dsp "hl.dsp.window.resize({x=$w,y=$h,exact=true})"
  dsp "hl.dsp.window.move({x=$x,y=$y})"
  echo "$c $w $h" > "$F"
}
load() { { [ -f "$F" ] && read -r CORNER SW SH < "$F"; } || { CORNER=br; SW=$((MW * FRAC_W / 100)); SH=$((SW * 9 / 16)); }; }

nearest_corner() { # canto mais proximo do centro atual da janela
  local cx=$((X + W / 2)) cy=$((Y + H / 2)) v h
  [ "$cy" -lt $((MY + MH / 2)) ] && v=t || v=b
  [ "$cx" -lt $((MX + MW / 2)) ] && h=l || h=r
  echo "$v$h"
}

case "${1:-toggle}" in
  toggle)
    if [ -f "$F" ]; then                       # PiP ativo -> volta ao tiling
      rm -f "$F"
      [ "$PINNED" = 1 ] && dsp "hl.dsp.window.pin({action='disable'})"
      dsp "hl.dsp.window.float({action='disable'})"
    else
      [ "$FLOAT" = 1 ] || dsp "hl.dsp.window.float({action='enable'})"
      load
      place "$CORNER" "$SW" "$SH"
    fi ;;
  pin)                                         # fixa/solta em todas as workspaces (so p/ flutuantes)
    [ "$FLOAT" = 1 ] || exit 0
    dsp "hl.dsp.window.pin({action='toggle'})" ;;
  corner)
    [ -f "$F" ] || exit 0
    load; place "${2:-$CORNER}" "$SW" "$SH" ;;
  next)
    [ -f "$F" ] || exit 0
    load
    case $CORNER in tr) n=br ;; br) n=bl ;; bl) n=tl ;; *) n=tr ;; esac
    place "$n" "$SW" "$SH" ;;
  nudge)
    [ "$FLOAT" = 1 ] || exit 0
    nx=$((X + ${2:-0})); ny=$((Y + ${3:-0}))
    # nao deixa sair da area util do monitor
    [ "$nx" -lt "$MX" ] && nx=$MX; [ "$nx" -gt $((MX + MW - W)) ] && nx=$((MX + MW - W))
    [ "$ny" -lt "$MY" ] && ny=$MY; [ "$ny" -gt $((MY + MH - H)) ] && ny=$((MY + MH - H))
    dsp "hl.dsp.window.move({x=$nx,y=$ny})" ;;
  size)
    [ -f "$F" ] || exit 0
    load
    if [ "${2:-+}" = "+" ]; then nw=$((SW * 115 / 100)); else nw=$((SW * 100 / 115)); fi
    [ "$nw" -lt 240 ] && nw=240; [ "$nw" -gt $((MW * 80 / 100)) ] && nw=$((MW * 80 / 100))
    nh=$((nw * 9 / 16))
    place "$(nearest_corner)" "$nw" "$nh" ;;
  *) sed -n '2,14p' "$0"; exit 1 ;;
esac
