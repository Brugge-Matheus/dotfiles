# Inicia o Hyprland automaticamente apenas no tty1 (boot elegante).
# Em outros TTYs (tty2-6) cai no shell normal, sem iniciar a sessao grafica.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-}" = "1" ]; then
  exec Hyprland
fi
