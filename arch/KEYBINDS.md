# ⌨️ Keybinds — Hyprland

> Documentação viva de todos os atalhos do desktop. Atualizada conforme as fases.
> **Tecla modificadora principal:** `SUPER` = tecla Windows (⊞).
> Fonte da verdade: [`hypr/hyprland.lua`](../hypr/hyprland.lua).

**Legenda:** ✅ ativo · ⏳ pendente (app ainda não instalado/configurado) · 🔜 planejado

---

## 🪟 Janelas & Foco

| Atalho | Ação | Status |
|---|---|---|
| `SUPER + Q` | Abrir terminal (ghostty) | ✅ |
| `SUPER + C` | Fechar janela ativa | ✅ |
| `SUPER + V` | Tela cheia (fullscreen — preenche o monitor, na frente) | ✅ |
| `SUPER + SHIFT + Space` | Alternar janela flutuante | ✅ |
| `SUPER + P` | Pseudo-tile (dwindle) | ✅ |
| `SUPER + J` | Alternar direção do split (dwindle) | ✅ |
| `SUPER + ← ↑ ↓ →` | Mover foco entre janelas | ✅ |
| `SUPER + LMB` (arrastar) | Mover janela | ✅ |
| `SUPER + RMB` (arrastar) | Redimensionar janela | ✅ |

## 🗂️ Workspaces

| Atalho | Ação | Status |
|---|---|---|
| `SUPER + 1..0` | Ir para o workspace 1–10 | ✅ |
| `SUPER + SHIFT + 1..0` | Mover janela para o workspace 1–10 | ✅ |
| `SUPER + scroll` | Ciclar entre workspaces | ✅ |
| `SUPER + S` | Abrir/fechar scratchpad ("magic") | ✅ |
| `SUPER + SHIFT + S` | Mover janela para o scratchpad | ✅ |
| 3 dedos (touchpad) | Trocar de workspace (gesture) | ✅ |

## 🚀 Aplicativos

| Atalho | Ação | Status |
|---|---|---|
| `SUPER + Q` | Terminal (ghostty) | ✅ |
| `SUPER + E` | Gerenciador de arquivos (thunar) | ✅ |
| `SUPER + Espaço` | Launcher de apps (rofi — busca com ícones) | ✅ |
| `SUPER + =` | Calculadora dev (variáveis de sessão, round(), qalc; Ctrl+Del apaga) | ✅ |
| `SUPER + T` | Tradutor (rofi + translate-shell: PT↔EN, copia) | ✅ |
| `SUPER + SHIFT + E` | Navegar arquivos pelo teclado (rofi-file-browser) | ✅ |
| `SUPER + ,` | Painel de configurações (settings-menu) | ✅ |

> Extensões do rofi documentadas em [`ROFI.md`](ROFI.md) (instalação, config e como usar).

## 🔊 Mídia & Hardware (teclas de função)

| Tecla | Ação | Status |
|---|---|---|
| `🔊 Volume +/−` | `wpctl` ajusta volume | ✅ |
| `🔇 Mute` | Mutar saída de áudio | ✅ |
| `🎤 Mic Mute` | Mutar microfone | ✅ |
| `☀️ Brilho +/−` | `brightnessctl` | ✅ |
| `⏯️ Play/Pause, ⏭️ Next, ⏮️ Prev` | `playerctl` | ✅ |

## ⚙️ Sessão

| Atalho | Ação | Status |
|---|---|---|
| `SUPER + L` | Bloquear a tela (hyprlock) | ✅ |
| `SUPER + N` | Abrir/fechar central de notificações (SwayNC) | ✅ |
| `SUPER + F` | Tela cheia (fullscreen — igual ao `SUPER + V`) | ✅ |
| `SUPER + SHIFT + F` | Tela cheia (fullscreen — igual ao `SUPER + V`) | ✅ |
| `SUPER + SHIFT + R` | Recarregar config do Hyprland | ✅ |
| `SUPER + M` | Encerrar a sessão (uwsm stop → volta ao login) | ✅ |

## 📸 Capturas & utilitários

| Atalho | Ação | Status |
|---|---|---|
| `SUPER + SHIFT + P` | Screenshot de região (abre o Satty p/ anotar) | ✅ |
| `SUPER + CTRL + P` | Screenshot da tela cheia (salva + copia) | ✅ |
| `SUPER + ALT + P` | Screenshot da janela ativa | ✅ |
| `SUPER + SHIFT + V` | Histórico de clipboard (cliphist) | ✅ |
| `SUPER + W` | Trocar wallpaper — escolhe o alvo (ambos ou um monitor) e a imagem | ✅ |

> Screenshots salvos em `~/Pictures/Screenshots` e copiados para o clipboard.
> Wallpapers lidos de `~/Pictures/Wallpapers`. O `SUPER + W` pergunta primeiro
> **onde** aplicar (Ambos os monitores / eDP-1 / HDMI-A-1) e depois a imagem.
> Aleatório em todos: `~/.config/waybar/scripts/wallpaper.sh random`.

## 🖱️ Cliques na Waybar

| Onde | Ação |
|---|---|
| Workspace (número) | Vai para o workspace **e leva o cursor junto** (só no clique; o teclado não move o mouse) |
| App aberto (ícone, centro) | Foca a janela (vai para o workspace dela) · (botão do meio) fecha |
| Spotify | Abre/foca o Spotify · (botão direito) play/pause |
| CPU | Abre `btop` |
| Volume | Mutar · (botão direito) `pavucontrol` · scroll = volume |
| Brilho | Scroll = ajusta brilho |
| Bluetooth | Abre `bluetoothctl` |
| Rede | Abre `nmtui` (config detalhada) · troca rápida no menu `SUPER + ,` |
| Clima | Atualiza · (hover) min/máx/sensação |
| Bateria | (hover) %, perfil de energia e tempo restante · (clique) menu de perfis (Performance/Equilibrado/Economia) |
| Relógio | Abre o calendário (gsimplecal) |
| Power () | Menu: bloquear/sair/suspender/reiniciar/desligar |

> Os menus (power/bateria) fecham com `Esc`, ao escolher, ou clicando no mesmo botão.

## 🎛️ Painel de configurações (`SUPER + ,`)

Menu único (fuzzel) que abre o app/ação de cada área — só lista o que está instalado:

| Item | Abre |
|---|---|
| Monitores | `nwg-displays` |
| Aparência | `nwg-look` |
| Teclado | Sub-menu: troca o layout (US Internacional ⇄ PT-BR ABNT2) em runtime |
| Bluetooth | `blueman-manager` |
| Som | `pavucontrol` |
| Rede | Menu Wi-Fi (fuzzel): lista redes, conecta, pede senha; liga/desliga o rádio |
| Impressoras | `system-config-printer` |
| Sistema | `xfce4-settings-manager` |

> A troca de layout do teclado vale por sessão (volta a US Internacional ao reiniciar o Hyprland).
