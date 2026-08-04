# 🚀 Rofi — launcher + extensões

O **rofi** é o launcher principal do desktop (`SUPER + Espaço`). Substituiu o walker
(que iniciava frio/lento e dependia de um daemon). O rofi 2.0+ roda **nativo no Wayland**,
abre instantâneo **sem daemon**, e é totalmente temável via `.rasi`.

> Config em [`../rofi/`](../rofi/) — symlinkada para `~/.config/rofi/` pelo `arch/install.sh`
> (a pasta **inteira**, então temas e scripts vão junto).

---

## 🎨 Tema

```
rofi/
├── config.rasi          # layout (quadrado, 30% largura, 6 linhas) + @import da paleta
├── colors-ayu.rasi      # paleta ayu-dark (mesma do LazyVim) — ATIVA
├── colors-black.rasi    # paleta black minimalista
└── scripts/
    ├── rofi-ext.sh          # lançador das extensões (chamado pelos binds)
    └── rofi-translate.sh    # tradutor (modo script do rofi)
```

**Trocar de tema = 1 linha** no topo do `config.rasi`:
```rasi
@import "colors-ayu.rasi"     /* paleta do LazyVim (ayu-dark) */
@import "colors-black.rasi"   /* black minimalista */
```

As cores ficam **isoladas** nos `colors-*.rasi` (variáveis `bg`, `fg`, `accent`, `sel`,
`sel-fg`, `urgent`, `border-c`). O `config.rasi` só cuida do layout e referencia essas
variáveis — então dá pra criar novos temas copiando um `colors-*.rasi` e ajustando os hex.

- **Fonte:** JetBrainsMono Nerd Font · **Ícones:** Papirus-Dark.
- Realce (`sel`) da paleta ayu usa o **laranja translúcido** (`#FF8F40` a ~40%).
  Intensidade = 2 últimos dígitos do hex (`40`≈25% · `66`≈40% · `99`≈60%).

---

## 🧩 Extensões

| Extensão | Atalho | Pacote | Origem |
|---|---|---|---|
| **Calculadora "dev"** (variáveis+round) | `SUPER + =` | `libqalculate` (`qalc`) | oficial |
| **Tradutor** (translate-shell) | `SUPER + T` | `translate-shell` | oficial |
| **Navegador de arquivos** | `SUPER + SHIFT + E` | `rofi-file-browser-extended` | AUR |

Todos são disparados pelo `rofi/scripts/rofi-ext.sh` (que os binds do Hyprland chamam).

### Instalação
```bash
# oficiais
sudo pacman -S rofi-calc translate-shell
# AUR
yay -S rofi-file-browser-extended
```
(Numa máquina nova, o `arch/install/02-visual.sh` + `arch/install.sh` já instalam tudo —
os pacotes estão em `packages/02-visual.txt` e `packages/02-visual-aur.txt`.)

---

### 🧮 Calculadora "dev" — `SUPER + =`
Extensão **nossa** (`rofi/scripts/rofi-calc-dev.sh`) sobre o **libqalculate** (`qalc`).
Vai além da calculadora simples: **variáveis de sessão**, funções e arredondamento.
Digite a conta e `Enter`; `Enter` numa linha (resultado ou variável) **copia** o valor.

**Variáveis de sessão** (o grande diferencial):
```
base = 10 - 2            → define base = 8
base * 10 / 100          → 0.8   (reusa a variável)
round(base * 10 / 100, 2) → 0.8  (arredonda p/ 2 casas)
preco = 100
desc = 15
round(preco * (1 - desc/100), 2) → 85
```

**Funções e conversões (tudo do qalc):**
```
2 + 2 * 10
round(3.14159, 2)        → 3.14
sqrt(2)
200 * 15%                → 30    (porcentagem: use "Y * X%", não "X% of Y")
100 USD to BRL           # conversão de moeda (precisa de internet)
2 GiB to MB              # conversão de unidade
hex(255) · sin(pi/4) · 2^10
```

**Comandos e teclas:**
| Ação | Como |
|---|---|
| Avaliar a conta digitada (e **auto-copiar** o resultado) | `Enter` |
| Definir variável | digitar `nome = expr` + `Enter` |
| Copiar o valor de uma linha selecionada | `Control + Enter` |
| **Apagar** a variável/entrada selecionada | `Control + Delete` |
| **Limpar todo o histórico** | `Control + Shift + Delete` (ou `:clearhist`) |
| Remover variável(is) por nome | `rm nome` · `rm a b c` |
| Remover todas as variáveis | `rm *` (ou `:clear`) |
| Listar variáveis | `:vars` |

> **Como funciona a tela:** você digita e dá `Enter` — a janela **fica aberta** (é um
> REPL), mostrando o resultado (já copiado) e o histórico/variáveis abaixo. Para fechar,
> `Esc`. (`Enter` sempre avalia o que você **digitou**; para copiar uma linha antiga use
> `Ctrl+Enter`.)

As variáveis são **momentâneas** (ficam em `~/.cache/rofi-calc-dev/`, some com `:clear`).
Por baixo: as variáveis são substituídas pelos valores antes de ir pro `qalc` (evita
colisão com palavras reservadas, ex.: `base`), e o `qalc` roda em base decimal fixa.

> **Nota:** o `rofi-calc` (plugin, `SUPER+= antigo`) continua instalado como alternativa
> "live" (calcula enquanto digita), mas o launcher usa a versão dev acima. No rofi-calc,
> `Shift+Delete` apaga uma entrada do histórico e `round(x,2)` também funciona.

---

### 🌐 Tradutor — `SUPER + T`
Extensão nossa (`rofi/scripts/rofi-translate.sh`) sobre o **translate-shell** (`trans`).
Digite o texto, `Enter` → aparecem **duas traduções**: para **PT-BR** e para **EN**
(não precisa escolher direção). `Enter` numa delas **copia** pro clipboard (`wl-copy`).

```
┌───────────────────────────────
│ Traduzir  hello world
│ Enter copia a tradução
│   pt   olá mundo
│   en   hello world
└───────────────────────────────
```
Requer internet (o `trans` consulta a API). Ajustes no script: mude os `-t pt`/`-t en`
para outros idiomas, ou adicione mais linhas de idioma.

---

### 📁 Navegador de arquivos — `SUPER + SHIFT + E`
`rofi-file-browser-extended`: navega o sistema de arquivos pelo teclado e abre o item
selecionado no app padrão (`xdg-open`). Complementa o `SUPER + E` (Thunar, GUI).

- Digite para filtrar; `Enter` entra na pasta / abre o arquivo; `..` volta.
- Config opcional em `~/.config/rofi/file-browser` (veja `man rofi-file-browser-extended`);
  por padrão começa na home e abre com o app associado.

Invocação por trás: `rofi -show file-browser-extended -modi file-browser-extended`.

---

## ➕ Criar suas próprias extensões
O rofi tem o **script mode**: qualquer script vira um "modo". O rofi chama o script,
ele imprime as opções (uma por linha); ao selecionar, o rofi chama de novo passando o
texto. Variáveis: `ROFI_RETV` (0=inicial, 1=selecionou), `ROFI_INFO` (metadado da linha).
Diretivas: `\0prompt\x1f...`, `\0message\x1f...`, `texto\0info\x1fVALOR`, `\0icon\x1f...`.

O `rofi-translate.sh` é um exemplo completo e comentado — use como molde. Depois é só:
1. pôr o script em `rofi/scripts/` (executável);
2. adicionar um `case` no `rofi-ext.sh`;
3. criar o bind no `hypr/hyprland.lua`.

---

## 🔧 Alternar modos DENTRO do rofi
No launcher principal (`SUPER + Espaço`) as abas do rodapé alternam entre
**Apps / Files / Run / Win**:

- **`Ctrl + Tab`** → próximo modo · **`Ctrl + Shift + Tab`** → modo anterior
- ou **clique nas abas** no rodapé

**Calc e Tradutor NÃO ficam nas abas** — só abrem pelos atalhos dedicados
(`SUPER + =` e `SUPER + T`). Motivo: são modos "script" e precisam do
`Enter = accept-custom` (avaliar o texto digitado). Na barra comum o `Enter` é
`accept-entry` (aceitar linha selecionada) e o modo **fecharia** ao digitar uma conta.
Os atalhos dedicados lançam o rofi com os keybinds corretos (ver `rofi/scripts/rofi-ext.sh`).

> ⚠️ O modo `file-browser-extended` é um **plugin**; o launcher só funciona depois que
> `rofi-file-browser-extended` estiver instalado (senão o rofi reclama de "mode not found").
> Os modos `calcd` e `trans` são scripts nossos (precisam de `qalc`/`libqalculate` e
> `translate-shell`, respectivamente).
