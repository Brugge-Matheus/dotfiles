# Arduino / ESP32 no Neovim — resumo técnico da implementação

Documento para passar a outro Claude (ou outra pessoa) assumir/estender o trabalho.
Dono: Matheus Brugge (pt-BR). Repo: `~/dotfiles` (symlink `~/.config/nvim -> ~/dotfiles/nvim`).

## Objetivo
Programar Arduino/ESP32 sem o Arduino IDE: compilar, gravar e usar o monitor serial dentro do
Neovim, e também só pelo terminal com o `arduino-cli`. Tem que funcionar no **Arch Linux
(Hyprland)** e no **macOS** (macOS não foi testado — só o Arch). Reaproveitar ao máximo o que já existe.

## Ambiente
- Neovim 0.12.3, LazyVim (lazy.nvim), snacks.nvim (picker, terminal, notifier), which-key, Mason.
- arduino-cli 1.5.1 (pacman `arduino-cli`; macOS `brew install arduino-cli`).
- Core `esp32:esp32` 3.3.12 + `arduino:avr` 1.8.8 já instalados em `~/.arduino15` (vieram do Arduino IDE 2,
  que compartilha o diretório de dados com o CLI). Libs em `~/Arduino/libraries` (ArduinoJson, DHT, PubSubClient).
- clangd 22.1.6 via Mason; parser treesitter `arduino`.

## Decisões de arquitetura (e porquê)
1. **arduino-cli é o backbone** (facade de preprocess + gcc cruzado + linker + esptool/avrdude + monitor).
   PlatformIO foi descartado: o oficial não suporta o core Arduino-ESP32 3.x (só o fork pioarduino).
2. **Plugin próprio fino em Lua** em vez de adotar `yuukiflow/Arduino-Nvim`: tinha atalhos `<leader>a*`
   (colidem com o grupo +ai: Claude Code/Copilot), sem quickfix de erros, sem opções de placa
   (ESP32 tem 13 menus: PartitionScheme, PSRAM…), `stty -f` BSD-only, ALS forçado.
3. **clangd direto** (não arduino-language-server, que não foi testado — download bloqueado pelo
   classificador de permissões). Limitação aceita: função usada antes de definida dá falso "undeclared"
   no editor (o arduino-builder gera protótipos, o clangd não). A compilação não é afetada.
4. **Estado no `sketch.yaml` oficial** (`default_fqbn`, `default_port`, `default_protocol`) — o CLI puro e
   o nvim compartilham o mesmo estado. Opções da placa vão dentro do FQBN (`esp32:esp32:esp32:PartitionScheme=huge_app,PSRAM=enabled`).
5. **Portabilidade**: nada de caminho fixo de dados — usa `arduino-cli config get directories.data`;
   portas via `arduino-cli board list --format json` (filtra Bluetooth/debug-console do macOS);
   `--query-driver` cobre `~/.arduino15` e `~/Library/Arduino15`.

## Arquivos
| Arquivo | O que faz |
|---|---|
| `nvim/lua/arduino/init.lua` | Todo o módulo (~600 linhas): comandos, pickers, compile/upload async, monitor, LSP, decode |
| `nvim/lua/config/autocmds.lua` | `require("arduino").setup()` no fim (carrega no VeryLazy) |
| `nvim/lua/plugins/c.lua` | clangd: `filetypes` inclui `arduino`; `cmd` ganhou `--query-driver=` (via `require("arduino").query_driver()`); treesitter ganhou `arduino` |
| `arch/packages/04-apps.txt` | + `arduino-cli`, `picocom` |
| `setup.sh` | + `arduino-cli picocom` em `BREW_PACKAGES` (macOS) |
| `docs/arduino-cli-manual.pdf` | Manual (9 págs, pt-BR, sem acentos) de uso pelo CLI + equivalência com os atalhos do nvim |

## Atalhos (somente em buffers `filetype=arduino`, prefixo `<leader>m`)
`mc` compilar · `mu` compilar+gravar (fecha o monitor antes, reabre depois) · `mm` monitor (toggle, split inferior,
baud lido de `Serial.begin(N)`, padrão 115200) · `mp` porta · `mb` placa · `mo` opções da placa · `ml` buscar/instalar lib ·
`mg` regenerar LSP · `md` decodificar backtrace (visual ou clipboard) · `mi` info · `mL` log cru do build · `mn` novo sketch.
Comandos equivalentes: `:ArduinoCompile :ArduinoUpload :ArduinoMonitor [baud] :ArduinoPort :ArduinoBoard :ArduinoOptions
:ArduinoLib :ArduinoLsp :ArduinoLog :ArduinoInfo :ArduinoNew [nome] :ArduinoDecode`.

## Como funciona (pontos não óbvios)
- **Sketch root**: `vim.fs.root` por `sketch.yaml`; senão dir do `.ino`. O arduino-cli exige `<pasta>/<pasta>.ino`
  (validado em `check_sketch`, com mensagem clara).
- **Build path** fora do projeto: `stdpath("cache")/arduino/<nome>-<sha10 do dir>`. Contém `.elf`, `.bin`,
  `compile_commands.json`.
- **Erros → quickfix**: parse das linhas `/abs/path:linha:col: error|warning: msg` (o builder já mapeia para o `.ino`
  original). Falha sem arquivo:linha (linker/upload) abre o log cru (`:ArduinoLog`).
- **LSP**: `arduino-cli compile --only-compilation-database` (~2,4 s) gera o DB no build path; o módulo escreve
  `.clangd` na pasta do sketch (com `# fqbn:` no cabeçalho para detectar troca de placa) e dá `:lsp restart clangd`.
  Receita validada (0 erros no sketch do ESP32): `CompilationDatabase: <build>`, `Remove:` de flags GCC-Xtensa que o clang
  desconhece (`-mlongcalls`, `-mfix-esp32-*`, `-fstrict-volatile-bitfields`, …) e `Add: ["-D__GLIBC_USE(x)=0"]`.
  `.clangd` é gerado — não commitar nos projetos de sketch. Regenera sozinho ao abrir `.ino` se faltar/for de outra placa
  (só quando já existe `sketch.yaml`).
- **Monitor**: `Snacks.terminal.open` em `position=bottom`, `auto_close=false`; há fallback para `:terminal` simples.
  Porta serial só aceita um cliente → upload fecha o monitor primeiro.
- **Decode de backtrace**: pega endereços `0x4xxxxxxx` do texto (os `0x3ff…` são pilha), acha o `*-addr2line` do core em
  `<data_dir>/packages/esp32/tools/*/*/bin/` conforme o chip (xtensa-esp32/s2/s3, riscv32-esp-elf p/ C2/C3/C5/C6/H2/P4),
  roda sobre `<build>/<sketch>.ino.elf` e joga o resultado no quickfix.
- Pickers usam `vim.ui.select`/`vim.ui.input` (o LazyVim já roteia para o snacks picker) — sem dependência nova.

## O que foi validado (Arch, headless + clangd real)
- Compilação do sketch via módulo (sizes na notificação); erro proposital (`pinModee`) → quickfix com arquivo/linha.
- `clangd --check` com o `.clangd` gerado: 0 erros; LSP anexa ao buffer `.ino` na config completa do LazyVim.
- Keymaps/comandos registrados; `:ArduinoDecode` mapeou o endereço real de `loop()` para `ventoinha.ino:38`.
- `arduino-cli board attach -b <fqbn com opções>` e `compile -e` (export em `build/esp32.esp32.esp32/`).

## NÃO validado / pendências
- **Upload e monitor com placa física** (nenhuma conectada nos testes).
- **macOS inteiro** (caminhos/portas seguem a doc oficial; lógica não rodou lá). **Uno/AVR** (`avr-gcc` no clangd) não testado.
- `arduino-language-server` não testado (plano B se o falso "undeclared" incomodar).
- Linux: `brltty` instalado pode derrubar `/dev/ttyUSB*` de CH340/CP210x; usuário já está no grupo `uucp`.
- PDF sem acentos (ASCII por segurança de fonte) — pode ser refeito com fonte TTF.
- `:ArduinoDecode` assume o `.elf` do mesmo build que está rodando na placa.

## Ideias futuras
Instalar core (`:ArduinoCore`), `arduino-cli upload` separado (sem recompilar), perfis no `sketch.yaml`, fallback ALS,
statusline (lualine) mostrando placa/porta.

## Outras mudanças desta sessão (contexto)
- `waybar/scripts/waybar-fullscreen.sh`: health-check que relança a barra de monitor que perdeu a layer-surface após suspend.
- `wireplumber/51-bluez-headset.conf`: codecs `aac sbc_xq sbc msbc cvsd` e `bluetooth.autoswitch-to-headset-profile = true`
  (voltou a ligar: com `false` o mic do headset não era usado nas calls do Discord).
- `nvim/lazy-lock.json`: bump de plugins (inclui `nvim-treesitter` e parser `arduino` instalado).
- Push nesse repo: a chave SSH autentica como outro usuário do GitHub; usar HTTPS com credenciais do `gh`.
