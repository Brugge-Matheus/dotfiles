#!/usr/bin/env bash
# =====================================================================
#  Migracao de rede: iwd + systemd-networkd  ->  NetworkManager
#  Rodar com: sudo bash arch/install/switch-to-networkmanager.sh
#
#  Estrategia: NetworkManager usando o IWD como BACKEND de WiFi.
#  Assim reaproveita o iwd (que ja funciona) e as redes ja salvas,
#  reconectando automaticamente sem redigitar senha.
#
#  REVERSIVEL: para voltar ao estado anterior:
#     sudo systemctl disable --now NetworkManager
#     sudo systemctl enable  --now systemd-networkd systemd-networkd.socket
# =====================================================================
set -uo pipefail

log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_warn() { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

[ "$(id -u)" -eq 0 ] || { log_err "Rode como root: sudo bash $0"; exit 1; }
command -v nmcli >/dev/null 2>&1 || { log_err "NetworkManager nao instalado."; exit 1; }

# Guarda o SSID atual (para tentar reconectar depois)
CUR_SSID="$(iwgetid -r 2>/dev/null)"
[ -z "$CUR_SSID" ] && CUR_SSID="$(iw dev 2>/dev/null | awk '/ssid/{print $2; exit}')"
[ -z "$CUR_SSID" ] && CUR_SSID="$(iwctl station wlan0 show 2>/dev/null | sed -n 's/.*Connected network[[:space:]]\{1,\}//p' | sed 's/[[:space:]]*$//')"
log_info "Rede WiFi atual detectada: ${CUR_SSID:-<desconhecida>}"

# 1) NetworkManager usa o iwd como backend de WiFi
log_info "Configurando NetworkManager para usar o backend iwd..."
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/wifi_backend.conf <<'EOF'
[device]
wifi.backend=iwd
EOF
log_ok "/etc/NetworkManager/conf.d/wifi_backend.conf"

# 2) Desliga o systemd-networkd (o NM passa a gerenciar o IP)
log_info "Desativando systemd-networkd (o NetworkManager assume)..."
systemctl disable --now systemd-networkd-wait-online.service 2>/dev/null || true
systemctl disable --now systemd-networkd.socket            2>/dev/null || true
systemctl disable --now systemd-networkd.service           2>/dev/null || true
# iwd continua ativo (backend do NM). systemd-resolved continua (DNS).
log_ok "systemd-networkd desativado."

# 3) Liga o NetworkManager
# Critico: ja desligamos o systemd-networkd acima. Se o NM nao subir, a maquina
# fica SEM REDE -> abortamos com instrucao de reversao em vez de seguir mudo.
log_info "Ativando NetworkManager..."
if ! systemctl enable --now NetworkManager.service; then
  log_err "Falha ao ativar o NetworkManager. Revertendo o systemd-networkd p/ nao ficar sem rede:"
  log_err "  sudo systemctl enable --now systemd-networkd.service systemd-networkd.socket"
  exit 1
fi
sleep 4

# 4) Tenta (re)conectar ao WiFi
if [ -n "$CUR_SSID" ]; then
  log_info "Tentando conectar a '$CUR_SSID' via NetworkManager..."
  nmcli device wifi connect "$CUR_SSID" 2>/dev/null || true
fi
sleep 4

# 5) Teste de conectividade
log_info "Testando conectividade..."
if ping -c 2 -W 3 1.1.1.1 >/dev/null 2>&1; then
  log_ok "Conectividade OK! Estado:"
  nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status | sed 's/^/   /'
  echo
  log_ok "Migracao concluida. A Waybar agora gerencia WiFi (clique -> nmtui)."
else
  log_warn "Sem conectividade automatica. Conecte manualmente:"
  echo "      nmtui                # interface de texto p/ escolher a rede"
  echo "   ou nmcli device wifi connect '<SSID>' password '<senha>'"
  echo
  log_warn "Se quiser REVERTER para o estado anterior:"
  echo "      sudo systemctl disable --now NetworkManager"
  echo "      sudo systemctl enable  --now systemd-networkd systemd-networkd.socket"
fi
