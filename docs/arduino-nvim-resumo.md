# Arduino / ESP32 no Neovim — resumo técnico da implementação

Documento para passar a outro Claude (ou outra pessoa) assumir/estender o trabalho.
Dono: Matheus Brugge (pt-BR). Repo: `~/dotfiles` (symlink `~/.config/nvim -> ~/dotfiles/nvim`).
Manual de uso (pelo CLI e pelo nvim): `docs/arduino-cli-manual.pdf`.

## Objetivo
Programar Arduino/ESP32 sem o Arduino IDE: compilar, gravar e usar o monitor serial dentro do Neovim, e também só
pelo terminal com o `arduino-cli`. Tem que funcionar no **Arch Linux (Hyprland)** e no **macOS** (macOS NÃO foi
testado — só o Arch). Reaproveitar ao máximo o que já existe.

## Ambiente
- Neovim 0.12.3, LazyVim (lazy.nvim), snacks.nvim (picker via `vim.ui.select`), which-key, Mason, blink.cmp.
- arduino-cli 1.5.1 (pacman `arduino-cli`; macOS `brew install arduino-cli`).
- Core `esp32:esp32` 3.3.12 + `arduino:avr` 1.8.8 já em `~/.arduino15` (vieram do Arduino IDE 2, que compartilha o
  diretório de dados com o CLI). Libs do usuário em `~/Arduino/libraries` (ArduinoJson, DHT, Adafruit Unified Sensor, PubSubClient).
- Placa de teste do usuário: ESP32 DevKit com **CP210x** (`10c4:ea60`), porta `/dev/ttyUSB0`.
- clangd 22.1.6 via Mason; parser treesitter `arduino`.

## Decisões de arquitetura (e porquê)
1. **arduino-cli é o backbone** (preprocess + gcc cruzado + linker + esptool/avrdude + monitor). PlatformIO descartado:
   o oficial não suporta o core Arduino-ESP32 3.x (só o fork pioarduino).
2. **Plugin próprio fino em Lua** em vez de adotar `yuukiflow/Arduino-Nvim`: atalhos `<leader>a*` colidem com o grupo +ai,
   sem quickfix, sem opções de placa (ESP32 tem 13 menus: PartitionScheme, PSRAM…), `stty -f` BSD-only, ALS forçado.
3. **clangd direto** (não arduino-language-server — download bloqueado pelo classificador de permissões, não testado).
   Limitação aceita: função usada antes de definida dá falso "undeclared" no editor (o builder gera protótipos, o clangd não).
4. **Estado no `sketch.yaml` oficial** (`default_fqbn`, `default_port`, `default_protocol`): CLI puro e nvim compartilham o
   estado. Opções da placa vão dentro do FQBN (`esp32:esp32:esp32:PartitionScheme=huge_app,PSRAM=enabled`).
5. **Portabilidade**: nada de caminho fixo — `arduino-cli config get directories.data`; portas via
   `arduino-cli board list --format json` (filtra Bluetooth/debug-console do macOS); `--query-driver` cobre
   `~/.arduino15` e `~/Library/Arduino15`; dono da porta via `lsof -t` (fallback `fuser`) + `ps`.

## Arquivos
| Arquivo | O que faz |
|---|---|
| `nvim/lua/arduino/init.lua` | Todo o módulo (~1250 linhas): comandos, pickers, compile/upload async, painéis log+monitor, LSP, decode |
| `nvim/lua/config/autocmds.lua` | `require("arduino").setup()` no fim (carrega no VeryLazy) |
| `nvim/lua/plugins/c.lua` | clangd: `filetypes` + `arduino`; `root_dir` → `require("arduino").clangd_root_dir`; `cmd` + `--query-driver=` e `--limit-results=300`; treesitter + `arduino` |
| `arch/packages/04-apps.txt` | + `arduino-cli`, `picocom` |
| `setup.sh` | + `arduino-cli picocom` em `BREW_PACKAGES` (macOS) |
| `docs/arduino-cli-manual.pdf` | Manual pt-BR (sem acentos): uso pelo CLI, problemas comuns, equivalência com os atalhos |
| `docs/arduino-nvim-resumo.md` | Este arquivo |

## Atalhos (globais, prefixo `<leader>m`; em buffer sem arquivo usam o último sketch, `state.last_dir`)
`mc` compilar · `mu` compilar+gravar (+ monitor automático) · `mm` mostra/oculta monitor · `mL` mostra/oculta log ·
`mp` porta · `mb` placa · `mB` baud do monitor · `mo` opções da placa · `ml` buscar/instalar lib · `mg` regenerar LSP · `md` decodificar backtrace
(visual ou clipboard) · `mi` info · `mn` novo sketch.
Comandos: `:ArduinoCompile :ArduinoUpload :ArduinoMonitor [baud] :ArduinoPort :ArduinoBoard :ArduinoOptions :ArduinoLib
:ArduinoBaud [n|auto] :ArduinoLsp :ArduinoLog :ArduinoInfo :ArduinoNew [nome] :ArduinoDecode`.

## Como funciona (pontos não óbvios)
- **Sketch root**: `vim.fs.root` por `sketch.yaml`; senão dir do `.ino`. O arduino-cli exige `<pasta>/<pasta>.ino`
  (`check_sketch` avisa). **Salva os buffers modificados do sketch antes de compilar/gerar LSP** (`save_sketch`): o CLI lê o
  ARQUIVO, não o buffer — sem isso um `#include` digitado e não salvo não entrava no build.
- **Build path** fora do projeto: `stdpath("cache")/arduino/<nome>-<sha10 do dir>` (`.elf`, `.bin`, `compile_commands.json`).
- **Erros → quickfix** (`/abs:linha:col: error|warning`), e Enter numa linha do log pula para o arquivo:linha.

### LSP (clangd)
- `arduino-cli compile --only-compilation-database` (~2,4 s) gera o DB; o módulo escreve `.clangd` na pasta do sketch
  (cabeçalho `# fqbn:` + `# tpl: N`; `TPL` sobe quando o template muda, regenerando os antigos) e reinicia o clangd.
  Receita validada (0 erros): `CompilationDatabase: <build>`, `Remove:` de flags GCC-Xtensa que o clang desconhece
  (`-mlongcalls`, `-mfix-esp32-*`, `-fstrict-volatile-bitfields`, …), `Add: ["-D__GLIBC_USE(x)=0"]`. `.clangd` é gerado —
  não commitar nos projetos de sketch.
- **Armadilhas corrigidas:**
  1. Sem `.clangd`/DB o clangd usa o comando *fallback* `clang -- x.ino`, que não monta AST → `clangd: -32001: invalid AST`.
     `root_dir` do clangd só inicia em buffers `arduino` se existir `.clangd` no sketch; `ensure_lsp` reinicia ou dispara
     `FileType` nos buffers abertos ao gerar o `.clangd`.
  2. O arduino-builder injeta `#include <Arduino.h>` no `.cpp` gerado, mas o clangd lê o `.ino` direto → fragmento
     `If: PathMatch: .*\.ino` + `Add: [-include, Arduino.h]`.
  3. O DB só tem `-I` das libs que o sketch JÁ inclui. Para `#include <` sugerir libs ainda não usadas, o fragmento `.ino` do
     `.clangd` recebe `-I<source_dir>` das libs **do usuário** (`lib list --all --fqbn X --format json`, `location ~= "platform"`).
     Libs do core (~44: WiFi, BLE…) NÃO entram: testado — as 48 empurravam `DHT.h` da posição ~27 para ~64 e as libs do usuário
     caíam fora do corte (clangd devolve só N itens, em ordem alfabética). Por isso também `--limit-results=300`
     (padrão 100) em `plugins/c.lua`.
  4. `#include` mudou e salvou (`BufWritePost *.ino`, hash dos includes) → regenera o DB e reinicia o clangd sozinho.
     `<leader>mg` e `:ArduinoLsp` sempre reiniciam. Instalar lib (`ml`) regenera e reinicia.

### Painéis log | monitor (embaixo, lado a lado)
- `mc/mu` abrem o *log do build* ao vivo (buffer persistente `arduino-cli://build`, ft `arduinolog`; o `\r` do esptool
  colapsa p/ o estado mais recente). Gravação OK → o *monitor* abre sozinho à direita do log (foco fica no código).
- Monitor = terminal nativo (`jobstart(..., {term=true})`), sem snacks. Ambos abrem e ficam no fim da saída (`follow()`:
  cursor na última linha + `zb`); rolar para cima pausa, `G` retoma.
- **`mm` oculta/mostra sem encerrar** (`bufhidden=hide`, a saída acumula escondida); **`q` dentro do monitor encerra**
  (`jobstop` + apagar buffer). Só esconder a janela com wipe/hide errado deixava o `arduino-cli monitor` vivo segurando a
  porta (`Serial port busy`) — bug real que mordeu o usuário. Upload fecha o monitor próprio antes (um cliente por porta).
- **Porta já em uso** (outra sessão de nvim, monitor órfão): `ensure_port_free` acha os donos (`lsof -t`/`fuser` + `ps`); se
  todos são `arduino-cli monitor` oferece "Assumir" (mata o `arduino-cli` pai do `serial-monitor`) ou "Cancelar"; se é outro
  programa (picocom, python…) só avisa. Não dá para "anexar" ao terminal de OUTRA instância do nvim — por isso o "assumir".

### Baud do monitor
`monitor_baud(dir)`: escolha salva (`stdpath("state")/arduino-baud.json`, por sketch) > `Serial.begin(N)` do código
(`code_baud`, lê o buffer se aberto) > 115200. `<leader>mB`/`:ArduinoBaud [n|auto]` (menu com 17 bauds + "Automático"); com o
monitor aberto ele reinicia no baud novo mantendo oculto/visível. `<leader>mi` mostra baud + origem, o `Serial.begin` do código,
estado do monitor e avisa (⚠) quando monitor ≠ código. O `info` é uma **janela flutuante** (`float_text`) que fica aberta até
`q`/`Esc`/`Enter`, dimensionada p/ caber o texto e com `wrap` exato (nenhum caractere é cortado, ao contrário do `vim.notify`). `Serial.begin(MACRO)` não é detectado (só número literal).

### Serial com lixo após gravar (hardware, mitigado em software)
- Sintoma: depois do upload, o monitor vira enxurrada de `�`. Medido: ~143 mil bytes/s de `00`/`80`, igual em qualquer baud
  (máx. físico de 115200 ≈ 11 mil B/s) → linha RX do CP210x presa em nível baixo (TX do ESP32 preso). **Cessa assim que o
  ESP32 transmite um byte** (reset → texto de boot, ou o sketch imprimindo). Reproduzível sem nvim e sem arduino-cli
  (python direto na porta: 5/6 tentativas). Não é DTR/RTS (`dtr=on,rts=on` também dá), nem timing do `arduino-cli`.
- Mitigação: `watch_flood` conta `U+FFFD` no buffer do monitor 1,5 s após abrir (só `fqbn ^esp32:`); se ≥100 fecha o monitor,
  reinicia a placa com o `esptool` do core (`M._reset_esp`: `esptool --port P --after hard-reset read-mac`) e reabre — até 3×.
  Validado: 6 gravações seguidas, em todas 1 reset automático bastou → 0 lixo.
- Causa raiz provável (não provada): reset automático marginal da placa. Remédios de hardware: capacitor 10 µF EN↔GND,
  outro cabo/porta USB. Sketch que imprime algo logo após o boot (ex.: `Serial.println("Boot ok")`) também limpa a linha.

### Decode de backtrace
Pega endereços `0x4xxxxxxx` (os `0x3ff…` são pilha), acha o `*-addr2line` do core em `<data_dir>/packages/esp32/tools/*/*/bin/`
conforme o chip (xtensa-esp32/s2/s3; riscv32-esp-elf p/ C2/C3/C5/C6/H2/P4), roda sobre `<build>/<sketch>.ino.elf` e joga no quickfix.

## O que foi validado (Arch, headless + clangd real + placa real)
- Compilar via módulo; erro proposital (`pinModee`) → quickfix e log com arquivo:linha; `clangd --check` 0 erros.
- Upload real do sketch led-btn (várias dezenas de gravações durante os testes, sempre o mesmo programa); monitor abre,
  oculta/mostra, `q` encerra, sem processos órfãos; assumir/cancelar monitor de outro processo; aviso para programa não-monitor.
- Completar `#include <DH…`/`<PubSub…`/`<ArduinoJ…` e lib recém-instalada (`ZZ_Teste.h`, criada e removida) aparecem.
- `:ArduinoDecode` mapeou o endereço real de `loop()` para `ventoinha.ino:38`.

## NÃO validado / pendências
- **macOS inteiro** (caminhos/portas seguem a doc oficial; lógica não rodou lá — alvo: MacBook Pro M4, Apple Silicon) e **Uno/AVR** (`avr-gcc` no clangd).
  - Verificado nos índices oficiais (20/11/2026): core `esp32:esp32` 3.3.12 tem toolchain, esptool e openocd `arm64-apple-darwin` (nativo). O `avr-gcc` do `arduino:avr` só tem `x86_64-apple-darwin` → **precisa de Rosetta 2** (o `setup.sh` instala).
  - `setup.sh` (macOS) agora instala Rosetta e os cores `esp32:esp32` + `arduino:avr` (no Mac não há `~/.arduino15` vindo do IDE).
  - Checklist do 1º uso no Mac: `brew install arduino-cli`; `arduino-cli core install esp32:esp32`; plugar a placa; `ls /dev/cu.*`; clone CP210x/CH340 pode exigir driver do fabricante; `:checkhealth`/`<leader>mi`.
- Menu do blink.cmp na tela do usuário (testado só o que o clangd devolve); `<leader>ml` com download real de lib nova.
- `arduino-language-server` não testado (plano B p/ o falso "undeclared").
- Linux: `brltty` pode derrubar `/dev/ttyUSB*` de CH340/CP210x; usuário já está no grupo `uucp`.
- PDF sem acentos (ASCII por segurança de fonte). `:ArduinoDecode` assume o `.elf` do mesmo build que roda na placa.
- Armadilha dos testes: `pkill -f`/`pgrep -fc` com texto que aparece na própria linha de comando do shell mata/conta o
  próprio harness — usar padrões ancorados (`^/usr/bin/arduino-cli monitor`) ou PID.

## Ideias futuras
`:ArduinoCore` (instalar core), `arduino-cli upload` separado (sem recompilar), perfis no `sketch.yaml`, fallback ALS,
lualine mostrando placa/porta, `<leader>mr` (reset da placa), opção de incluir libs do core na completação por demanda.

## Outras mudanças do mesmo período (contexto)
- `waybar/scripts/waybar-fullscreen.sh`: health-check que relança a barra de monitor que perdeu a layer-surface após suspend.
- `wireplumber/51-bluez-headset.conf`: codecs `aac sbc_xq sbc msbc cvsd` e `bluetooth.autoswitch-to-headset-profile = true`.
- `nvim/lazy-lock.json`: bump de plugins (inclui `nvim-treesitter` e o parser `arduino`).
- Push neste repo: a chave SSH autentica como outro usuário do GitHub; usar HTTPS com credenciais do `gh`.
