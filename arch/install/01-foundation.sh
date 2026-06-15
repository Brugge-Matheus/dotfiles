#!/usr/bin/env bash
# =====================================================================
#  FASE 0 — Fundacao do sistema (Arch + Hyprland)
#  Rodar com: sudo bash arch/install/01-foundation.sh
#
#  O que faz (idempotente):
#   1. Instala drivers/pacotes da fundacao (ver arch/packages/01-foundation.txt)
#   2. Configura o NVIDIA Optimus para Wayland em modo OFFLOAD (estavel):
#        - Intel (i915) dirige o painel
#        - NVIDIA carrega depois, disponivel via `prime-run`
#   3. Regenera o initramfs (UKI)
#
#  IMPORTANTE — armadilha conhecida (Optimus):
#   NAO colocar os modulos NVIDIA em early-KMS no initramfs (MODULES=(nvidia...))
#   nem usar `fbdev=1`. Nesse notebook o painel pertence a Intel; forcar a
#   NVIDIA cedo no boot causa TELA PRETA. Este script usa a config conhecida-boa.
#
#  NAO faz (de proposito):
#   - Trocar a rede para NetworkManager (fica para a Fase 2)
#   - Ativar servicos de usuario (PipeWire/symlinks) -> ver arch/install.sh
# =====================================================================
set -euo pipefail

# --- logging (mesmo estilo do setup.sh do repo) ---
log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_warn() { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

# --- guardas ---
if [ "$(id -u)" -ne 0 ]; then
  log_err "Rode como root: sudo bash $0"
  exit 1
fi
if ! command -v pacman >/dev/null 2>&1; then
  log_err "Este script e exclusivo para Arch Linux (pacman nao encontrado)."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="$SCRIPT_DIR/../packages/01-foundation.txt"

# ---------------------------------------------------------------------
# 1. Pacotes
# ---------------------------------------------------------------------
log_info "Lendo lista de pacotes: $PKG_FILE"
mapfile -t PKGS < <(grep -vE '^\s*#|^\s*$' "$PKG_FILE" | awk '{print $1}')
log_info "Instalando ${#PKGS[@]} pacotes da fundacao..."
pacman -Syu --needed --noconfirm "${PKGS[@]}"
log_ok "Pacotes instalados."

# ---------------------------------------------------------------------
# 2. NVIDIA Optimus -> modo OFFLOAD (config conhecida-boa)
# ---------------------------------------------------------------------
log_info "Configurando modprobe do NVIDIA (modeset=1, SEM fbdev=1)..."
cat > /etc/modprobe.d/nvidia.conf <<'EOF'
# NVIDIA em modo OFFLOAD (Optimus). A Intel dirige a tela.
# modeset=1 e necessario para PRIME render offload no Wayland.
# NAO usar fbdev=1 aqui (causa tela preta neste notebook hibrido).
options nvidia_drm modeset=1
EOF
log_ok "/etc/modprobe.d/nvidia.conf"

log_info "Garantindo que NVIDIA NAO esta no early-KMS do initramfs..."
if grep -qE '^MODULES=.*nvidia' /etc/mkinitcpio.conf; then
  cp -n /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak 2>/dev/null || true
  # Remove APENAS os tokens nvidia* da linha MODULES, preservando os demais
  # (ex.: i915), depois normaliza espacos. NAO zera a lista inteira.
  sed -i -E '/^MODULES=/{ s/\bnvidia(_[a-z]+)?\b//g; s/\(\s+/(/; s/\s+\)/)/; s/[[:space:]]{2,}/ /g }' /etc/mkinitcpio.conf
  log_warn "Removido nvidia de MODULES (estava em early-KMS)."
fi
log_ok "MODULES: $(grep '^MODULES' /etc/mkinitcpio.conf)"

log_info "Instalando hook do pacman p/ regenerar initramfs em updates do NVIDIA..."
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/nvidia.hook <<'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-open-dkms

[Action]
Description=Regenerando initramfs apos update do NVIDIA...
Depends=mkinitcpio
When=PostTransaction
Exec=/usr/bin/mkinitcpio -P
EOF
log_ok "/etc/pacman.d/hooks/nvidia.hook"

# ---------------------------------------------------------------------
# 3. Regenerar initramfs (UKI)
# ---------------------------------------------------------------------
log_info "Regenerando initramfs/UKI..."
mkinitcpio -P
log_ok "initramfs regenerado."

echo
echo "=============================================================="
echo " FASE 0 (fundacao) concluida."
echo " A config NVIDIA usada e a conhecida-boa (offload, sem tela preta)."
echo
echo " Proximos passos:"
echo "   1) Reinicie:  sudo reboot   (NAO edite a cmdline no limine)"
echo "   2) Apos voltar, rode (SEM sudo):  bash arch/install.sh"
echo "      -> cria symlinks de config e ativa servicos de usuario"
echo "=============================================================="
