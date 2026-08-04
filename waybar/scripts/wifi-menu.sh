#!/usr/bin/env bash
# Menu de Wi-Fi (fuzzel) usando NetworkManager (nmcli).
# Lista redes (● = conectada,  = protegida), conecta com 1 clique,
# pede senha no proprio fuzzel quando necessario, liga/desliga o radio.
set -uo pipefail

CFG="$HOME/.config/fuzzel/powermenu.ini"
fz() { fuzzel --dmenu --config "$CFG" "$@"; }

# --- radio desligado: oferece ligar ---
if [ "$(nmcli radio wifi 2>/dev/null)" != "enabled" ]; then
  ch="$(printf '  Ligar Wi-Fi\n  Cancelar' | fz --width 24 --lines 2 --prompt 'Wi-Fi> ')" || exit 0
  case "$ch" in *Ligar*) nmcli radio wifi on && notify-send -t 1500 "Wi-Fi" "Ligado";; esac
  exit 0
fi

# pede um rescan (ignora se foi recente demais)
nmcli dev wifi rescan 2>/dev/null || true

# --- monta a lista de redes (display \t ssid \t security) ---
# (o proprio python chama o nmcli: nada de pipe, pra nao colidir com o stdin do heredoc)
menu="$(python3 - <<'PY'
import subprocess
def unesc(line):
    parts=[]; cur=''; i=0
    while i < len(line):
        c=line[i]
        if c=='\\' and i+1 < len(line): cur+=line[i+1]; i+=2; continue
        if c==':': parts.append(cur); cur=''; i+=1; continue
        cur+=c; i+=1
    parts.append(cur); return parts

out=subprocess.run(['nmcli','-t','-f','ACTIVE,SIGNAL,SECURITY,SSID','dev','wifi','list'],
                   capture_output=True, text=True).stdout
seen={}
for line in out.splitlines():
    p=unesc(line)
    if len(p) < 4: continue
    active = p[0]=='yes'
    try: signal=int(p[1])
    except ValueError: signal=0
    security=p[2]
    ssid=':'.join(p[3:])
    if not ssid: continue  # rede oculta
    cur=(active,signal,security,ssid)
    if ssid not in seen or signal > seen[ssid][1]:
        seen[ssid]=cur

LOCK=''  # cadeado
rows=sorted(seen.values(), key=lambda r:(not r[0], -r[1]))
for active,signal,security,ssid in rows:
    secured = bool(security) and security != '--'
    mark = '●' if active else ' '   # ●
    disp = f"{mark} {ssid}" + (f"  {LOCK}" if secured else "")
    print(f"{disp}\t{ssid}\t{security}")
PY
)"

# entradas de controle no rodape
menu="$menu
  Desligar Wi-Fi\t__off__\t
  Atualizar lista\t__rescan__\t"

# conta linhas para dimensionar o fuzzel
n="$(printf '%s\n' "$menu" | grep -c . )"
[ "$n" -gt 12 ] && n=12

chosen="$(printf '%s' "$menu" | cut -f1 | fz --width 32 --lines "$n" --prompt 'Wi-Fi> ')" || exit 0
[ -z "$chosen" ] && exit 0

# recupera ssid + security da linha escolhida
rec="$(awk -F'\t' -v d="$chosen" '$1==d{print; exit}' <<<"$menu")"
ssid="$(cut -f2 <<<"$rec")"
sec="$(cut -f3 <<<"$rec")"

case "$ssid" in
  __off__)    nmcli radio wifi off && notify-send -t 1500 "Wi-Fi" "Desligado"; exit 0 ;;
  __rescan__) exec "$0" ;;
esac
[ -z "$ssid" ] && exit 0

# ja existe conexao salva? sobe direto (sem pedir senha)
if nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$ssid"; then
  if nmcli connection up id "$ssid" >/dev/null 2>&1; then
    notify-send -t 2000 "Wi-Fi" "Conectado a $ssid"
  else
    notify-send -u critical -t 3000 "Wi-Fi" "Falha ao conectar em $ssid"
  fi
  exit 0
fi

# rede aberta: conecta sem senha
if [ -z "$sec" ] || [ "$sec" = "--" ]; then
  if nmcli dev wifi connect "$ssid" >/dev/null 2>&1; then
    notify-send -t 2000 "Wi-Fi" "Conectado a $ssid"
  else
    notify-send -u critical -t 3000 "Wi-Fi" "Falha ao conectar em $ssid"
  fi
  exit 0
fi

# rede protegida e nova: pede senha (campo oculto no fuzzel)
pass="$(: | fz --password --lines 0 --width 32 --prompt "Senha ($ssid)> ")" || exit 0
[ -z "$pass" ] && exit 0
if nmcli dev wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
  notify-send -t 2000 "Wi-Fi" "Conectado a $ssid"
else
  notify-send -u critical -t 3000 "Wi-Fi" "Senha incorreta ou falha em $ssid"
fi
