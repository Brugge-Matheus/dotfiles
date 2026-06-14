#!/usr/bin/env bash
# =====================================================================
#  FASE 6 — Boot elegante: quiet + Plymouth + autologin -> hyprlock
#  Rodar com: sudo bash arch/install/06-boot-experience.sh
#
#  O que faz (idempotente, com REDE DE PROTECAO):
#   0. Backup do UKI atual + entrada "Arch Linux (resgate)" no limine
#   1. Instala Plymouth, adiciona o hook ao initramfs e define tema dark
#   2. Acrescenta 'quiet splash ...' ao /etc/kernel/cmdline
#   3. Autologin SO no tty1 (tty2-6 seguem pedindo senha)
#   4. Regenera o UKI (aborta se mkinitcpio falhar)
#
#  IMPORTANTE: mexe no BOOT. Mantem timeout do limine >= 3 e cria entrada
#  de resgate para que, se algo falhar, o boot anterior continue acessivel.
# =====================================================================
set -euo pipefail

log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_warn() { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

[ "$(id -u)" -eq 0 ] || { log_err "Rode como root: sudo bash $0"; exit 1; }
command -v pacman >/dev/null 2>&1 || { log_err "Exclusivo para Arch."; exit 1; }

USERNAME="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
[ -n "$USERNAME" ] || { log_err "Nao identifiquei o usuario (rode via sudo)."; exit 1; }

UKI="/boot/EFI/Linux/arch-linux.efi"
LIMINE="/boot/limine/limine.conf"
CMDLINE="/etc/kernel/cmdline"
MKINIT="/etc/mkinitcpio.conf"

# ---------------------------------------------------------------------
# 0. REDE DE PROTECAO — backup do UKI + entrada de resgate no limine
# ---------------------------------------------------------------------
log_info "Criando rede de protecao (backup do UKI + entrada de resgate)..."
if [ -f "$UKI" ] && [ ! -f "${UKI}.bak" ]; then
  cp "$UKI" "${UKI}.bak"
  log_ok "Backup do UKI: ${UKI}.bak"
fi
# timeout >= 3 (NAO some o menu) e entrada de resgate apontando p/ o .bak
if [ -f "$LIMINE" ]; then
  cp -n "$LIMINE" "${LIMINE}.bak" 2>/dev/null || true
  sed -i 's/^timeout:.*/timeout: 1/' "$LIMINE"
  if ! grep -q "Arch Linux (resgate)" "$LIMINE"; then
    ORIG_CMDLINE="$(grep -m1 -E '^\s*cmdline:' "$LIMINE" | sed 's/^\s*cmdline:\s*//')"
    cat >> "$LIMINE" <<EOF

/Arch Linux (resgate)
    protocol: efi
    path: boot():/EFI/Linux/arch-linux.efi.bak
    cmdline: ${ORIG_CMDLINE}
EOF
    log_ok "Entrada de resgate adicionada ao limine."
  fi
fi

# ---------------------------------------------------------------------
# 1. Plymouth + uwsm: instala, hook no initramfs e tema dark
# ---------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="$SCRIPT_DIR/../packages/06-boot.txt"
mapfile -t PKGS < <(grep -vE '^\s*#|^\s*$' "$PKG_FILE" | awk '{print $1}')
log_info "Instalando: ${PKGS[*]}"
pacman -Syu --needed --noconfirm "${PKGS[@]}"

log_info "Adicionando o hook 'plymouth' ao initramfs..."
if ! grep -qE '^HOOKS=.*\bplymouth\b' "$MKINIT"; then
  cp -n "$MKINIT" "${MKINIT}.bak" 2>/dev/null || true
  # insere 'plymouth' logo apos 'udev'
  sed -i -E 's/^(HOOKS=\([^)]*\budev\b)/\1 plymouth/' "$MKINIT"
  log_ok "HOOKS: $(grep '^HOOKS' "$MKINIT")"
else
  log_ok "Hook plymouth ja presente."
fi

log_info "Definindo tema dark do Plymouth..."
THEME="spinner"   # minimalista: spinner em fundo preto (sempre incluso)
plymouth-set-default-theme "$THEME" >/dev/null 2>&1 && log_ok "Tema: $THEME" \
  || log_warn "Nao consegui definir o tema (segue assim mesmo)."

# ---------------------------------------------------------------------
# 2. quiet/splash no cmdline
# ---------------------------------------------------------------------
log_info "Montando cmdline (quiet/splash + anti-flicker)..."
cp -n "$CMDLINE" "${CMDLINE}.bak" 2>/dev/null || true
# BASE = cmdline ORIGINAL (do backup) -> reconstrucao deterministica/idempotente
BASE="$(cat "${CMDLINE}.bak")"
# quiet/splash + silencia systemd + i915.fastboot (evita o reset de modo = piscar)
ADD="quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 systemd.show_status=false rd.systemd.show_status=false i915.fastboot=1"
CUR="$(echo "$BASE $ADD" | tr -s ' ' | sed 's/^ *//; s/ *$//')"
echo "$CUR" > "$CMDLINE"
log_ok "cmdline (UKI): $(cat "$CMDLINE")"

# ---------------------------------------------------------------------
# 2b. IMPORTANTE: o limine PASSA a sua propria 'cmdline:' (sobrepoe a do UKI).
#     Sincroniza a 1a entrada do limine com a cmdline completa (com quiet).
#     A entrada de resgate (2a cmdline:) fica intacta (sem quiet -> mostra logs).
# ---------------------------------------------------------------------
if [ -f "$LIMINE" ]; then
  log_info "Sincronizando a cmdline da entrada principal do limine (com quiet)..."
  sed -i "0,/^[[:space:]]*cmdline:/s|^\([[:space:]]*cmdline:\).*|\1 ${CUR}|" "$LIMINE"
  log_ok "limine entrada principal: $(grep -m1 -E '^\s*cmdline:' "$LIMINE" | sed 's/^\s*cmdline:\s*//')"
fi

# ---------------------------------------------------------------------
# 3. Autologin SO no tty1
# ---------------------------------------------------------------------
log_info "Configurando autologin no tty1 (usuario: $USERNAME)..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${USERNAME} --noclear %I \$TERM
EOF
log_ok "Autologin tty1 configurado (tty2-6 seguem pedindo senha)."

# ---------------------------------------------------------------------
# 4. Regenera o UKI (aborta se falhar)
# ---------------------------------------------------------------------
log_info "Regenerando o initramfs/UKI..."
if mkinitcpio -P; then
  log_ok "UKI regenerado."
else
  log_err "mkinitcpio FALHOU. NAO reinicie ainda — restaure o backup:"
  echo "   sudo cp ${UKI}.bak ${UKI}"
  echo "   sudo cp ${MKINIT}.bak ${MKINIT}; sudo cp ${CMDLINE}.bak ${CMDLINE}"
  exit 1
fi

echo
echo "=============================================================="
echo " BOOT ELEGANTE configurado."
echo " Ao reiniciar: splash do Plymouth -> entra sozinho -> hyprlock."
echo
echo " >>> Rode 'bash arch/install.sh' (sem sudo) p/ criar o symlink"
echo "     do ~/.zprofile, e entao reinicie: sudo reboot"
echo
echo " Resgate (se o boot falhar): no menu do limine escolha"
echo " 'Arch Linux (resgate)'."
echo "=============================================================="
