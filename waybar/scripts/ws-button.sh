#!/usr/bin/env bash
# Botao de um workspace (modulo custom/wsN). Saida JSON p/ waybar.
# Mostra o numero se o workspace esta OCUPADO (tem janela) ou e o ATIVO;
# caso contrario devolve vazio + classe "empty" (o CSS colapsa -> some).
# Clique (no config) troca via hl.dsp.focus -> funciona na build Lua e warpa o cursor.
set -uo pipefail
N="${1:?uso: ws-button.sh <numero>}"

WSS="$(hyprctl -j workspaces 2>/dev/null || echo '[]')"
ACT="$(hyprctl -j activeworkspace 2>/dev/null || echo '{}')"

python3 - "$N" "$WSS" "$ACT" <<'PY'
import json, sys
n = int(sys.argv[1])
try: wss = json.loads(sys.argv[2] or "[]")
except Exception: wss = []
try: act = json.loads(sys.argv[3] or "{}")
except Exception: act = {}

windows = {w.get("id"): w.get("windows", 0) for w in wss}
active_id = act.get("id")

if n == active_id:
    print(json.dumps({"text": str(n), "tooltip": f"Workspace {n} (ativo)", "class": "active"}))
elif windows.get(n, 0) > 0:
    print(json.dumps({"text": str(n), "tooltip": f"Workspace {n}", "class": "occupied"}))
else:
    print(json.dumps({"text": "", "class": "empty"}))
PY
