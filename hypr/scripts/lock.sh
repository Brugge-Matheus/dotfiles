#!/usr/bin/env bash
# =====================================================================
#  lock.sh — trava a sessao com hyprlock de forma RESILIENTE.
#
#  Por que existir: um "hl.exec_cmd(hyprlock)" simples roda o hyprlock UMA
#  vez. Se ele travar ou for morto (crash, kill -9), o desktop fica exposto
#  sem senha. Como o boot e por autologin (sem senha no tty1), o hyprlock e
#  a UNICA porta -> ele precisa se comportar como uma tela de login de fato:
#  se morrer sem autenticar, RELANCA. So libera a sessao quando o usuario
#  digita a senha certa (hyprlock sai com 0).
#
#  Usado em 3 lugares (todos passam por aqui p/ ganhar a resiliencia):
#   - autostart do hyprland.lua (trava no boot)
#   - SUPER+L  -> loginctl lock-session -> hypridle lock_cmd
#   - idle/antes de suspender -> hypridle lock_cmd
# =====================================================================
set -u

# Ja existe um hyprlock rodando? (ex.: idle disparando enquanto ja travado)
# Nao duplica a tela — apenas confirma que esta travado.
pidof hyprlock >/dev/null 2>&1 && exit 0

while :; do
  start=$(date +%s)
  # --grace 0: exige a senha imediatamente (sem janela de desbloqueio sem senha).
  # Nesta versao do hyprlock 'grace' so existe via CLI, nao no config.
  hyprlock --grace 0 "$@" && exit 0   # exit 0 = senha correta -> libera a sessao

  # Saiu != 0 = morreu SEM desbloquear (crash/kill). Relanca p/ nao expor o
  # desktop. Se caiu rapido demais (ex.: erro de config), espera p/ nao
  # consumir CPU num loop apertado.
  [ $(( $(date +%s) - start )) -lt 2 ] && sleep 2
done
