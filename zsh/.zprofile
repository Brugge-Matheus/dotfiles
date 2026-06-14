# Inicia o Hyprland via uwsm (Universal Wayland Session Manager) apenas no tty1.
# uwsm gerencia a sessao Wayland no systemd (graphical-session.target, env, etc.).
# Em outros TTYs cai no shell normal (sem iniciar a sessao grafica).
if [ "${XDG_VTNR:-}" = "1" ] && command -v uwsm >/dev/null 2>&1 && uwsm check may-start; then
  exec uwsm start hyprland.desktop
fi
