#!/usr/bin/env bash
# =====================================================================
#  FASE 9 — Impressao (CUPS) + Xerox Phaser 3020 via USB
#  Rodar com: sudo bash arch/install/09-printing.sh
#
#  O que faz (idempotente):
#   1. Instala a stack do CUPS (repo) + usbutils + system-config-printer
#   2. Confere o driver do Phaser 3020 (AUR: xerox-phaser-3020) — se faltar,
#      ORIENTA a instalar com yay (AUR nao instala como root) e ABORTA
#   3. Poe o usuario nos grupos 'lp' (acesso ao device) e 'sys' (admin do CUPS)
#   4. Habilita/reinicia o cups
#   5. AUTO-DETECTA a URI usb:// da impressora e o PPD, e adiciona no CUPS
#      como destino "Phaser3020" (default). Se a impressora nao for detectada,
#      tenta descarregar o modulo usblp e re-detectar.
#
#  Pre-requisito do driver (rode ANTES, como usuario normal):
#      yay -S --needed xerox-phaser-3020
# =====================================================================
set -uo pipefail

log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok()   { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_warn() { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
log_err()  { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

[ "$(id -u)" -eq 0 ] || { log_err "Rode como root: sudo bash $0"; exit 1; }
command -v pacman >/dev/null 2>&1 || { log_err "Exclusivo para Arch."; exit 1; }

TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
[ -n "$TARGET_USER" ] || { log_err "Nao identifiquei o usuario (rode via sudo)."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="$SCRIPT_DIR/../packages/09-printing.txt"

# ---------------------------------------------------------------------
# 1. Pacotes do repo
# ---------------------------------------------------------------------
mapfile -t PKGS < <(grep -vE '^\s*#|^\s*$' "$PKG_FILE" | awk '{print $1}')
log_info "Instalando (repo): ${PKGS[*]}"
pacman -Syu --needed --noconfirm "${PKGS[@]}" || { log_err "Falha no pacman."; exit 1; }
log_ok "Stack do CUPS instalada."

# ---------------------------------------------------------------------
# 2. Driver do Phaser 3020 (AUR) — precisa estar instalado antes
# ---------------------------------------------------------------------
find_ppd() { find /usr/share/ppd /usr/share/cups/model -iname '*3020*.ppd' 2>/dev/null | grep -v '_fr\.ppd' | head -1; }
PPD="$(find_ppd)"
if [ -z "$PPD" ] || [ ! -x /usr/lib/cups/filter/rastertospl ]; then
  log_err "Driver do Phaser 3020 ausente (sem PPD e/ou filtro rastertospl)."
  echo
  echo "    O driver vem do AUR e NAO instala como root. Rode como SEU usuario:"
  echo "        yay -S --needed xerox-phaser-3020"
  echo "    e depois rode este script de novo."
  exit 1
fi
log_ok "Driver presente. PPD: $PPD"

# ---------------------------------------------------------------------
# 3. Grupos: lp (device) + sys (admin do CUPS / SystemGroup no Arch)
# ---------------------------------------------------------------------
for g in lp sys; do
  if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx "$g"; then
    log_ok "Usuario ja no grupo $g."
  else
    gpasswd -a "$TARGET_USER" "$g" >/dev/null && log_ok "Adicionado ao grupo $g (efetivo apos relogar)."
  fi
done

# ---------------------------------------------------------------------
# 4. Servico do CUPS
# ---------------------------------------------------------------------
systemctl enable --now cups.socket cups.service >/dev/null 2>&1
systemctl restart cups.service
sleep 1
log_ok "cups ativo."

# ---------------------------------------------------------------------
# 5. Detecta a URI USB e adiciona o destino
#    NOTA: NAO blacklistamos o usblp de proposito. Ele fornece /dev/usb/lp*,
#    usado por impressoras termicas/POS (ESC/POS) — blacklistar quebraria o
#    PDV. O CUPS usa libusb e convive com o usblp. Se o lpinfo nao listar a
#    impressora, a causa quase sempre e ela estar PRESA NUMA VM (passthrough
#    USB e exclusivo) — solte da VM; em ultimo caso, 'sudo modprobe -r usblp'.
# ---------------------------------------------------------------------
detect_uri() { lpinfo -v 2>/dev/null | grep -iE 'phaser|3020|xerox' | grep -oE 'usb://[^ ]+' | head -1; }

URI=""
for _ in 1 2 3 4 5; do URI="$(detect_uri)"; [ -n "$URI" ] && break; sleep 1; done

if [ -z "$URI" ]; then
  log_err "Nao detectei a Phaser 3020 no CUPS."
  echo "    1) A impressora esta presa numa VM? (passthrough USB e exclusivo) -> solte da VM."
  echo "    2) Ligada e conectada? 'lsusb | grep -i xerox'"
  echo "    3) 'sudo lpinfo -v' deve listar uma linha usb://...Phaser..."
  exit 1
fi
log_ok "URI detectada: $URI"

PRINTER="Phaser3020"
log_info "Adicionando destino '$PRINTER' no CUPS..."
lpadmin -p "$PRINTER" -E -v "$URI" -P "$PPD" \
  && lpadmin -d "$PRINTER" \
  && cupsenable "$PRINTER" 2>/dev/null \
  && cupsaccept "$PRINTER" 2>/dev/null \
  && log_ok "Impressora '$PRINTER' adicionada e definida como padrao." \
  || { log_err "Falha ao adicionar a impressora via lpadmin."; exit 1; }

echo
echo "=============================================================="
echo " Impressao configurada."
echo "   Status:        lpstat -t"
echo "   Pagina teste:  lp -d $PRINTER /usr/share/cups/data/testprint"
echo "   GUI:           system-config-printer"
echo " (Saia e entre na sessao p/ valerem os grupos lp/sys.)"
echo "=============================================================="
lpstat -t 2>/dev/null | head