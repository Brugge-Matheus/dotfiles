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
| **Limpar todo o histórico** | `clear` · `Control + Shift + Delete` (ou `:clearhist`) |
| Remover variável(is) por nome | `rm nome` · `rm a b c` |
| Remover todas as variáveis | `clear vars` · `rm *` (ou `:clear`) |
| Limpar histórico **e** variáveis | `clear all` |
| Listar variáveis | `:vars` |

> **Estes atalhos valem no `SUPER + =`** (texto puro). Na aba do launcher escreva `>` antes (`>clear`, `>2+2`) e confirme com `Ctrl+Enter`.
>
> **Como funciona a tela:** você digita e dá `Enter` — a janela **fica aberta** (é um
> REPL), mostrando o resultado (já copiado) e o histórico/variáveis abaixo. Para fechar,
> `Esc`. (`Enter` sempre avalia o que você **digitou**; para copiar uma linha antiga use
> `Ctrl+Enter`.)

As variáveis são **momentâneas** (ficam em `~/.cache/rofi-calc-dev/`; `clear vars` / `clear all` zeram).
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
Cada tradução fica no **histórico** (`~/.cache/rofi-translate/`, as 6 últimas na lista); `Enter` numa linha copia, `>clear` limpa.
Requer internet para traduzir (o `trans` consulta a API). Ajustes no script: mude os `-t pt`/`-t en`
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
**Apps / Arquivos / Comandos / Janelas / Calculadora / Tradutor**:

- **`Tab`** → próximo modo · **`Shift + Tab`** → modo anterior (circular: Apps → Arquivos → Comandos → Janelas → Calculadora → Tradutor → Apps)
- também valem `Ctrl + Tab` / `Ctrl + Shift + Tab` e `Shift + ←/→`
- ou **clique nas abas** no rodapé
- Para andar **pela lista** use as `↑ ↓`, `Ctrl + j / k` ou `Ctrl + n / p` (o Tab não anda mais pela lista)

As 6 abas, da esquerda para a direita (ícones no rodapé):

| Aba | Modo | O que faz |
|---|---|---|
| **Apps** | `drun` | apps instalados, com ícone |
| **Arquivos** | `file-browser-extended` | navega pastas e abre com `xdg-open`; `Shift+Enter` = "abrir com…"; `Alt+1` abre sem fechar; `Alt+2` mostra/oculta ocultos (config em `rofi/file-browser`) |
| **Comandos** | `cmds` (`rofi/scripts/rofi-cmds.sh`) | paleta de ações do sistema + executa qualquer comando (ver abaixo); **substitui o `run` nativo**, que listava ~3.700 executáveis |
| **Janelas** | `win` (`rofi/scripts/rofi-windows.sh`) | janelas abertas com **ícone, app, PID, memória, workspace e estado**; `Enter` foca; `kill`/`term`/`close` por texto (ver abaixo). **Substitui o `window` nativo** |
| **Calculadora** | `calcd` | calculadora dev (variáveis, `qalc`) com **histórico** salvo; `>clear` limpa |
| **Tradutor** | `trans` | PT⇄EN com **histórico** salvo (precisa de internet para traduzir); `>clear` limpa |

### Comandos com `>` (em qualquer aba)

Para **escrever um comando** em qualquer aba, comece com `>`. Há **dois jeitos**, e a diferença é o **espaço** depois do `>`:

| Jeito | A lista | Executa com |
|---|---|---|
| `>comando` (sem espaço) | **continua visível** (você lê PIDs, nomes...) | **`Ctrl + Enter`** |
| `> comando` (com espaço) | **some** (modo comando) | **`Enter`** (ou `Ctrl + Enter`) |

Por que: o `Enter` sempre faz a **ação da linha selecionada** (abrir app, focar janela, copiar...). Com a lista visível há uma linha
selecionada, então `>clear` + `Enter` age nela — e não limpa nada. Com `> clear` (espaço) a lista fica vazia, não há linha, e o
`Enter` executa o texto digitado. O `Ctrl + Enter` sempre executa o texto, com ou sem lista.

- O texto **antes** do `>` continua filtrando e escolhe o alvo: `zen >kill!` / `zen > kill!` mostram só o Zen e matam esse processo.
- Sem `>` o texto é **só busca** — nada executa por engano.
- Abre o launcher com `rofi -show drun -matching-negate-char '>'` (já está no `menu` de `hypr/hyprland.lua`). O rofi não aceita essa
  opção no `.rasi`. Tradeoff: o `-` deixa de negar (`-foo` não exclui mais).
- Limite do jeito sem espaço: o que vem depois do 1º termo do comando ainda filtra a lista (na aba Janelas o PID está na linha, então
  `>kill! 1741909` mantém a linha do processo visível).

| Escreva | Faz |
|---|---|
| `>pavucontrol` | roda o comando em segundo plano (qualquer aba) |
| `>t df -h` | roda num terminal que espera `Enter` ao terminar |
| `zen >kill!` · `>kill! 1741909` · `>kill zen` | encerra a força (ver aba Janelas) |
| `>2+2*3` | na aba **Calculadora**, avalia a conta |
| `>hello world` | na aba **Tradutor**, traduz |

Nas abas **Apps** e **Arquivos** quem recebe o texto é `rofi/scripts/rofi-dispatch.sh` (via `run-command`); o resultado sai por notificação,
porque essas abas não têm linha de mensagem para scripts. Nas abas de script o resultado aparece na linha de mensagem.

**Comandos (aba):** lista ações com descrição (reiniciar serviços, tempo de bloqueio, wallpaper, PiP, screenshots, Wi-Fi, energia…).
`Enter` executa a ação escolhida. Digite `>comando` e `Ctrl+Enter` para um comando livre. Se o programa não existe, avisa e continua aberto.
Guarda os 8 últimos comandos livres como "recentes". Para acrescentar uma ação, edite a lista `ACTIONS` no topo do script
(`id|rótulo|descrição|comando`).

**Janelas:** a lista vem do `hyprctl` (a mais recente primeiro, como um alt-tab). Linha: `ícone App  PID · MB · ws · estado  título`.
`Enter` numa linha foca a janela (troca de workspace/monitor). Comandos (`>` + `Ctrl+Enter`):

| Escreva | Faz |
|---|---|
| `filtro >kill!` | filtra a lista por `filtro` e mata o **único** processo que sobra |
| `>kill <pid ou nome>` | encerra a **força** (`kill -9`) o processo e os filhos (sem helper órfão) |
| `>kill! <pid ou nome>` | igual, mas **confirma** quando o PID tem várias janelas (ex.: 2 terminais Ghostty = 1 processo) |
| `>term <pid ou nome>` | pede com educação (`SIGTERM`) |
| `>close <pid ou nome>` | fecha só a janela; o app decide |
| `>qualquer outra coisa` | roda como comando de shell (igual à aba Comandos) |

O alvo é o **app ou a classe** (nunca o título, para não matar o app errado) ou o PID. Se casar com mais de um processo,
**nada é morto**: ele lista os candidatos. Só alvos que aparecem na lista são aceitos. O resultado
(`✓ kill -9 em Zen Browser (PID …)`) aparece na linha de mensagem e a lista é atualizada.

**Calculadora e Tradutor** também continuam nos atalhos dedicados (`SUPER + =` e `SUPER + T`):
- **Calculadora (aba):** escreva `>conta` (ex.: `>2+2*3`) e `Ctrl + Enter`; `>nome = expr` define variável, `>rm nome` apaga.
  `Enter` numa linha do histórico **copia** o resultado. Sem `>` o texto só filtra o histórico.
  **No atalho `SUPER + =`** nada mudou: o texto puro vale (sem `>`), `Enter` avalia, `Ctrl+Enter` copia e `Ctrl+Delete` apaga
  uma entrada (o `rofi-ext.sh` exporta `ROFI_STANDALONE=1` e passa essas teclas só lá).
- **Tradutor (aba):** escreva `>texto` e `Ctrl + Enter` (traduz para PT e EN). No atalho `SUPER + T` o texto puro continua
  valendo. Sem internet, avisa em vez de fechar e o histórico segue consultável.

**Histórico (Calculadora e Tradutor, mesmo jeito)**
- Cada conta/tradução fica salva em `~/.cache/rofi-calc-dev/` e `~/.cache/rofi-translate/` e **sobrevive a fechar o rofi e a reiniciar**.
  Aparece na lista (a mais recente primeiro); `Enter` numa linha **copia** o resultado/tradução.
- A calculadora mostra as 15 últimas contas; o tradutor as 6 últimas traduções (cada uma com a linha PT e a linha EN e o texto
  original) e guarda até 30. Repetir o mesmo texto no tradutor só o sobe para o topo.
- **Limpar — o mesmo comando nas duas abas:**

  | Escreva (+ `Ctrl+Enter`) | Faz |
  |---|---|
  | `>clear` | limpa o **histórico** |
  | `>clear vars` | (só calculadora) limpa as **variáveis** |
  | `>clear all` | (só calculadora) limpa histórico **e** variáveis |

  Nos atalhos dedicados o `>` também vale para esses comandos (`>clear`). No tradutor, `clear` sozinho é reservado como comando;
  para traduzir a palavra, escreva mais de uma (`>clear text`). Na calculadora os antigos `:clearhist` e `:clear` seguem funcionando.
- Os ícones das abas Calculadora/Tradutor/Comandos vêm do prompt emitido pelo próprio script.
- **Placeholder:** é um só para todas as abas (`Buscar app, arquivo, janela ou comando…`), porque o rofi não aceita placeholder por aba; a Calculadora e o Tradutor explicam o uso na linha de mensagem abaixo da busca.

> ⚠️ O modo `file-browser-extended` é um **plugin**; o launcher só funciona depois que
> `rofi-file-browser-extended` estiver instalado (senão o rofi reclama de "mode not found").
> Os modos `calcd` e `trans` são scripts nossos (precisam de `qalc`/`libqalculate` e
> `translate-shell`, respectivamente).
