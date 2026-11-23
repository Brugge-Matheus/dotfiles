# 🎨 Tema — "Terminal Refinado"

Mesmo design do blog **bruggeOnGrails** (direção *Terminal Refinado*): monospace, preto quase-preto,
texto off-white e **um único acento âmbar**. Bordas de 1px, cantos de 2px, sem sombras berrantes.

| Papel | Cor | Onde |
|---|---|---|
| Fundo | `#0b0b0c` | waybar, rofi, swaync, hyprlock, ghostty |
| Painel / hover | `#101012` / `#16161a` | cards, barra de busca, seleção |
| Borda | `#22222a` (forte `#30303a`) | janelas inativas, divisórias |
| Texto | `#e7e7e6` | texto principal |
| Texto apagado / fraco | `#8a8a8f` / `#55555a` | detalhes, workspaces inativos |
| **Acento (âmbar)** | `#d6a84a` (claro `#eac884`, escuro `#8a6e31`) | borda da janela ativa, workspace ativo, cursor, seleção |
| Verde / Vermelho | `#7ba96a` / `#c87067` | tocando, carregando / erro, crítico, falha de senha |

**Fonte:** JetBrains Mono (Nerd Font). **Rótulos:** minúsculos ou MAIÚSCULOS com `letter-spacing`.

Onde está aplicado:

| Área | Arquivos |
|---|---|
| Hyprland (bordas, gaps, rounding, dim, grupos, fundo) | `hypr/hyprland.lua` |
| Lockscreen | `hypr/hyprlock.conf` |
| Barra / tooltips | `waybar/style.css` |
| Notificações / central | `swaync/style.css` |
| Launcher (rofi) / power menu (fuzzel) | `rofi/colors-brugge.rasi`, `fuzzel/powermenu.ini` |
| Terminal | `ghostty/config` (paleta ANSI, sem barra de rolagem/faixa cinza) |
| tmux / prompt | `tmux/.tmux.conf`, `starship/starship.toml` |
| Neovim | `nvim/colors/brugge.lua` (+ lualine) — colorscheme `brugge` |
| Apps GTK / Qt | `gtk-3.0/gtk.css`, `gtk-4.0/gtk.css`, `qt6ct/colors/brugge.conf` |
| mpv / qimgv / btop | `mpv/mpv.conf`, `qimgv/theme.conf`, `btop/themes/brugge.theme` |
| Wallpaper | `python3 arch/scripts/gen-brugge-wallpaper.py` -> `~/Pictures/Wallpapers/brugge-terminal.png` |

Fonte do design: projeto *bruggeOnGrails* no Claude Design (`direction-1-terminal.jsx`).
