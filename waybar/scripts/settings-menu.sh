#!/usr/bin/env bash
# Painel de configuracoes — menu unico (fuzzel) que abre o app de cada area.
# Glifos via chr() no python (fonte ASCII).
set -euo pipefail

if pgrep -x fuzzel >/dev/null; then pkill -x fuzzel; exit 0; fi

# (icone, label, comando)  — so lista o que estiver instalado
build_menu() {
python3 - <<'PY'
import shutil, os
kbd = os.path.expanduser("~/.config/waybar/scripts/keyboard-layout.sh")
wifi = os.path.expanduser("~/.config/waybar/scripts/wifi-menu.sh")
lock = os.path.expanduser("~/.config/waybar/scripts/lock-timeout.sh")
restart = os.path.expanduser("~/.config/hypr/scripts/hypr-restart.sh") + " --gui"
items = [
    (0xF108, "Monitores",    "nwg-displays"),
    (0xF1FC, "Aparencia",    "nwg-look"),
    (0xF11C, "Teclado",      kbd),
    (0xF294, "Bluetooth",    "blueman-manager"),
    (0xF028, "Som",          "pavucontrol"),
    (0xF1EB, "Rede",         wifi),
    (0xF023, "Tempo de bloqueio", lock),
    (0xF02F, "Impressoras",  "system-config-printer"),
    (0xF013, "Sistema",      "xfce4-settings-manager"),
    (0xF021, "Reiniciar serviços", restart),
]
for cp, label, cmd in items:
    exe = cmd.split()[0]
    if shutil.which(exe) or (os.path.sep in exe and os.access(exe, os.X_OK)):
        print(f"{chr(cp)}   {label}\t{cmd}")
PY
}

menu="$(build_menu)"
[ -z "$menu" ] && { notify-send "Configuracoes" "Nenhum app de settings instalado."; exit 0; }

# mostra so o rotulo (1a coluna ate o TAB); retorna o comando (apos o TAB)
chosen="$(cut -f1 <<<"$menu" | fuzzel --dmenu --config "$HOME/.config/fuzzel/powermenu.ini" \
  --anchor center --width 26 --lines 10)" || exit 0
[ -z "$chosen" ] && exit 0

cmd="$(awk -F'\t' -v sel="$chosen" '$1==sel{print $2}' <<<"$menu")"
mkdir -p "$HOME/.cache"
# erros do item escolhido ficam em ~/.cache/settings-menu.log (antes iam para /dev/null e nao dava p/ saber por que nada abriu)
[ -n "$cmd" ] && { echo "$(date '+%F %T') abrindo: $cmd" >>"$HOME/.cache/settings-menu.log"; setsid -f $cmd >>"$HOME/.cache/settings-menu.log" 2>&1; }
