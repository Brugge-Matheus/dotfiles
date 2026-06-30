#!/usr/bin/env bash
# Clique no botao de workspace N (modulos custom/ws*):
#   1) troca para o workspace via hl.dsp.focus  (forma que funciona na config Lua)
#   2) LEVA O CURSOR junto, explicitamente — so no clique. O warp global
#      (cursor:warp_on_change_workspace) fica 0 de proposito p/ o TECLADO nao
#      mover o mouse; aqui movemos a mao so quando voce clica na barra.
# Destino do cursor: centro da janela focada; se o workspace estiver vazio,
# centro do monitor que passa a exibi-lo.
set -uo pipefail
N="${1:?uso: ws-focus.sh <numero>}"

hyprctl dispatch "hl.dsp.focus({workspace=$N})" >/dev/null 2>&1
sleep 0.05   # deixa o foco assentar antes de ler a geometria

# 1) tenta o centro da janela ativa (se estiver no workspace alvo)
WIN="$(hyprctl -j activewindow 2>/dev/null || echo '{}')"
read -r CX CY < <(python3 - "$N" "$WIN" <<'PY'
import json, sys
n = int(sys.argv[1])
try: w = json.loads(sys.argv[2] or "{}")
except Exception: w = {}
at = w.get("at"); sz = w.get("size")
ws = (w.get("workspace") or {}).get("id")
if at and sz and ws == n:
    print(int(at[0] + sz[0] / 2), int(at[1] + sz[1] / 2))
PY
)

# 2) workspace vazio -> centro do monitor que mostra o workspace N
if [ -z "${CX:-}" ]; then
  MONS="$(hyprctl -j monitors 2>/dev/null || echo '[]')"
  read -r CX CY < <(python3 - "$N" "$MONS" <<'PY'
import json, sys
n = int(sys.argv[1])
try: mons = json.loads(sys.argv[2] or "[]")
except Exception: mons = []
for m in mons:
    if (m.get("activeWorkspace") or {}).get("id") == n:
        sc = m.get("scale", 1) or 1
        print(int(m["x"] + (m["width"]/sc)/2), int(m["y"] + (m["height"]/sc)/2))
        break
PY
)
fi

[ -n "${CX:-}" ] && hyprctl dispatch "hl.dsp.cursor.move({x=$CX,y=$CY})" >/dev/null 2>&1
exit 0
