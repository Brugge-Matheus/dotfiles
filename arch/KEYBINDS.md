# ⌨️ Keybinds — Hyprland

> Documentação viva de todos os atalhos do desktop. Atualizada conforme as fases.
> **Tecla modificadora principal:** `SUPER` = tecla Windows (⊞).
> Fonte da verdade: [`hypr/hyprland.lua`](../hypr/hyprland.lua).

**Legenda:** ✅ ativo · ⏳ pendente (app ainda não instalado/configurado) · 🔜 planejado

---

## 🪟 Janelas & Foco

| Atalho | Ação | Status |
|---|---|---|
| `SUPER + Q` | Abrir terminal (kitty) | ✅ |
| `SUPER + C` | Fechar janela ativa | ✅ |
| `SUPER + V` | Alternar janela flutuante | ✅ |
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
| `SUPER + Q` | Terminal (kitty) | ✅ |
| `SUPER + E` | Gerenciador de arquivos | ⏳ (app a definir — Fase 4) |
| `SUPER + Espaço` | Launcher de apps (walker) | ✅ |

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
| `SUPER + F` | Maximizar janela | ✅ |
| `SUPER + SHIFT + F` | Tela cheia (real) | ✅ |
| `SUPER + SHIFT + R` | Recarregar config do Hyprland | ✅ |
| `SUPER + M` | Sair do Hyprland (volta ao TTY/login) | ✅ |

---

## 🔜 Planejado (próximas fases)

Atalhos que vamos adicionar conforme instalarmos as ferramentas. **Nada disso está ativo ainda** — serve de mapa:

| Atalho (proposto) | Ação | Fase |
|---|---|---|
| `Print` / `SUPER + SHIFT + S` | Screenshot (grim + slurp) | 3 |
| `SUPER + SHIFT + V` | Histórico de clipboard (cliphist) | 3 |
| `SUPER + W` | Trocar wallpaper | 3 |
| `SUPER + Backspace` | Power menu (logout/reboot/shutdown) | 3 |
| `SUPER + period` | Seletor de emoji | 3 |
