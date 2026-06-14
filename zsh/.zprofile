# Inicia o Hyprland via uwsm (Universal Wayland Session Manager) apenas no tty1.
# uwsm gerencia a sessao Wayland no systemd (graphical-session.target, env, etc.).
# Em outros TTYs cai no shell normal (sem iniciar a sessao grafica).
# A saida vai para um log (nao para o TTY) -> evita avisos do xkbcomp na tela no boot.
if [ "${XDG_VTNR:-}" = "1" ] && command -v uwsm >/dev/null 2>&1 && uwsm check may-start; then
  exec uwsm start hyprland.desktop >"${XDG_CACHE_HOME:-$HOME/.cache}/hyprland-session.log" 2>&1
fi
