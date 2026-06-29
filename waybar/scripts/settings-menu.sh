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
items = [
    (0xF108, "Monitores",    "nwg-displays"),
    (0xF1FC, "Aparencia",    "nwg-look"),
    (0xF11C, "Teclado",      kbd),
    (0xF294, "Bluetooth",    "blueman-manager"),
    (0xF028, "Som",          "pavucontrol"),
    (0xF1EB, "Rede",         "nm-connection-editor"),
    (0xF02F, "Impressoras",  "system-config-printer"),
    (0xF013, "Sistema",      "xfce4-settings-manager"),
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
  --anchor center --width 26 --lines 8)" || exit 0
[ -z "$chosen" ] && exit 0

cmd="$(awk -F'\t' -v sel="$chosen" '$1==sel{print $2}' <<<"$menu")"
[ -n "$cmd" ] && setsid -f $cmd >/dev/null 2>&1
