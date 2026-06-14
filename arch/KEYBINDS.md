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
| `SUPER + R` | Launcher de apps | ⏳ (a definir — Fase 2) |

## 🔊 Mídia & Hardware (teclas de função)

| Tecla | Ação | Status |
|---|---|---|
| `🔊 Volume +/−` | `wpctl` ajusta volume | ✅ |
| `🔇 Mute` | Mutar saída de áudio | ✅ |
| `🎤 Mic Mute` | Mutar microfone | ✅ |
| `☀️ Brilho +/−` | `brightnessctl` | ⏳ (instalar `brightnessctl` — Fase 2) |
| `⏯️ Play/Pause, ⏭️ Next, ⏮️ Prev` | `playerctl` | ⏳ (instalar `playerctl` — Fase 2) |

## ⚙️ Sessão

| Atalho | Ação | Status |
|---|---|---|
| `SUPER + M` | Sair do Hyprland (volta ao TTY/login) | ✅ |

---

## 🔜 Planejado (próximas fases)

Atalhos que vamos adicionar conforme instalarmos as ferramentas. **Nada disso está ativo ainda** — serve de mapa:

| Atalho (proposto) | Ação | Fase |
|---|---|---|
| `SUPER + SHIFT + R` | Recarregar config do Hyprland | 2 |
| `SUPER + F` | Tela cheia | 2 |
| `SUPER + SHIFT + Space` | Alternar flutuante (alt) | 2 |
| `Print` / `SUPER + SHIFT + S` | Screenshot (grim + slurp) | 3 |
| `SUPER + W` | Trocar wallpaper | 3 |
| `SUPER + L` | Bloquear tela (hyprlock) | 3 |
| `SUPER + N` | Centro de notificações | 3 |
| `SUPER + Backspace` | Power menu (logout/reboot/shutdown) | 3 |
| `SUPER + period` | Seletor de emoji | 3 |
| `SUPER + V` (clipboard) | Histórico de clipboard | 3 |

> ⚠️ Conflito a resolver: `SUPER + V` hoje é "flutuante" e está proposto para clipboard.
> Decidiremos os bindings finais na Fase 2/3 (provavelmente flutuante → `SUPER + SHIFT + Space`).
