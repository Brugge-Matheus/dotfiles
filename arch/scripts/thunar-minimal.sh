#!/usr/bin/env bash
# Ajustes minimalistas do Thunar (via xfconf). Idempotente.
# Rodar: bash arch/scripts/thunar-minimal.sh  (sem sudo)
set -euo pipefail
command -v xfconf-query >/dev/null 2>&1 || { echo "xfconf-query ausente"; exit 0; }

set_prop() { xfconf-query -c thunar -p "$1" -n -t "$2" -s "$3" 2>/dev/null \
             || xfconf-query -c thunar -p "$1" -s "$3" 2>/dev/null || true; }

set_prop /last-menubar-visible       bool   false                 # esconde a barra de menus (usa o hamburguer)
set_prop /last-location-bar          string ThunarLocationButtons # caminho em "migalhas"
set_prop /last-side-pane             string ThunarShortcutsPane   # sidebar de atalhos (Lugares)
set_prop /last-show-hidden           bool   false                 # nao mostra ocultos por padrao
set_prop /misc-single-click          bool   false                 # duplo clique p/ abrir
set_prop /last-details-view-column-widths string "" 2>/dev/null || true
set_prop /last-window-maximized      bool   false
set_prop /misc-middle-click-in-tab   bool   true                  # clique do meio abre em nova aba

echo "Thunar: ajustes minimalistas aplicados."
