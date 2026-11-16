-- Arduino / ESP32 no Neovim — cola fina por cima do `arduino-cli`.
--
-- O arduino-cli faz o trabalho pesado (pré-processar .ino, gcc cruzado, linker,
-- esptool/avrdude, monitor serial). Este módulo só:
--   * guarda placa/porta no `sketch.yaml` oficial (o CLI puro também lê)
--   * compila/grava async e joga os erros no quickfix
--   * abre o monitor serial num split (terminal do snacks)
--   * pickers (vim.ui.select → snacks) de porta, placa, opções da placa e libs
--   * gera `.clangd` + compile_commands p/ o clangd entender o ESP32/AVR
--   * decodifica backtrace do ESP32 (addr2line do próprio core)
--
-- Funciona em Linux e macOS: nada de caminho fixo — diretórios e portas vêm do
-- próprio arduino-cli (`config get`, `board list --format json`).

local M = {}

local TITLE = "Arduino"
local L = vim.log.levels
local state = { monitor = nil, logbuf = nil, data_dir = nil, last_dir = nil, inc = {} }

-- ───────────────────────── util ─────────────────────────

local function notify(msg, level, id)
  vim.notify(msg, level or L.INFO, { title = TITLE, id = id })
end

local function cli()
  local p = vim.fn.exepath("arduino-cli")
  if p == "" then
    -- fallback: o que vem embutido no Arduino IDE 2
    for _, c in ipairs({
      "/opt/arduino-ide/resources/app/lib/backend/resources/arduino-cli",
      "/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli",
    }) do
      if vim.fn.executable(c) == 1 then
        return c
      end
    end
    notify("arduino-cli não encontrado.\n  Arch:  sudo pacman -S arduino-cli\n  macOS: brew install arduino-cli", L.ERROR)
    return nil
  end
  return p
end

--- roda o arduino-cli sem bloquear; cb(res) no loop principal.
--- opts.on_output(chunk): recebe stdout+stderr ao vivo (res.stdout/stderr ficam vazios)
local function run(args, cb, opts)
  local bin = cli()
  if not bin then
    return
  end
  local cmd = { bin }
  vim.list_extend(cmd, args)
  local o = { text = true, cwd = opts and opts.cwd }
  local on_output = opts and opts.on_output
  if on_output then
    local function h(_, data)
      if data then
        vim.schedule(function()
          on_output(data)
        end)
      end
    end
    o.stdout, o.stderr = h, h
  end
  vim.system(cmd, o, function(res)
    vim.schedule(function()
      cb(res)
    end)
  end)
end

local function json(args, cb)
  run(args, function(res)
    local ok, data = pcall(vim.json.decode, res.stdout or "")
    if res.code ~= 0 or not ok then
      notify(("arduino-cli %s falhou:\n%s"):format(args[1], vim.trim((res.stderr or "") .. (res.stdout or ""))), L.ERROR)
      return
    end
    cb(data)
  end)
end

local function read(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

local function write(path, content)
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
end

-- ───────────────────── painéis: log do build | monitor serial ─────────────────────
-- Ficam embaixo da tela, lado a lado:   [ log do build | monitor serial ]
-- Cada um fecha/abre sozinho (<leader>mL e <leader>mm) sem afetar o outro.

local function win_of(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end
  local w = vim.fn.bufwinid(buf)
  return w > 0 and w or nil
end

--- cursor na última linha da janela (o terminal/log "segue" a saída nova)
local function follow(w)
  if w and vim.api.nvim_win_is_valid(w) then
    local b = vim.api.nvim_win_get_buf(w)
    pcall(vim.api.nvim_win_set_cursor, w, { vim.api.nvim_buf_line_count(b), 0 })
    pcall(vim.api.nvim_win_call, w, function()
      vim.cmd("normal! zb")
    end)
  end
end

--- janela nova embaixo; se o outro painel estiver aberto, divide ao lado dele
local function bottom_win(other, place)
  if other then
    vim.api.nvim_set_current_win(other)
    vim.cmd((place == "left" and "leftabove" or "rightbelow") .. " vsplit")
  else
    vim.cmd("botright 14split")
  end
  local w = vim.api.nvim_get_current_win()
  vim.wo[w].winfixheight = true
  vim.wo[w].number, vim.wo[w].relativenumber, vim.wo[w].signcolumn = false, false, "no"
  return w
end

local function log_buf()
  if state.logbuf and vim.api.nvim_buf_is_valid(state.logbuf) then
    return state.logbuf
  end
  local b = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_name, b, "arduino-cli://build")
  vim.bo[b].buftype, vim.bo[b].bufhidden, vim.bo[b].swapfile = "nofile", "hide", false
  vim.bo[b].modifiable, vim.bo[b].filetype = false, "arduinolog"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = b, silent = true, desc = "Ocultar log" })
  vim.keymap.set("n", "<cr>", function()
    M.log_jump()
  end, { buffer = b, silent = true, desc = "Ir p/ arquivo:linha do erro" })
  state.logbuf = b
  return b
end

local function log_set(lines)
  local b = log_buf()
  vim.bo[b].modifiable = true
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  vim.bo[b].modifiable = false
end

local function show_log()
  local b = log_buf()
  local w = win_of(b)
  if w then
    return w
  end
  local cur = vim.api.nvim_get_current_win()
  w = bottom_win(win_of(state.monitor and state.monitor.buf), "left")
  vim.api.nvim_win_set_buf(w, b)
  vim.wo[w].wrap = true
  vim.wo[w].winbar = "  Build log   (q oculta · Enter pula p/ o erro · G segue o fim)"
  follow(w)
  if vim.api.nvim_win_is_valid(cur) then
    vim.api.nvim_set_current_win(cur) -- foco continua no código
  end
  return w
end

--- começa um log novo e devolve { feed(chunk), finish(footer) } p/ saída ao vivo
--- (esptool usa \r p/ barra de progresso: mostramos só o estado mais recente)
local function log_stream(header)
  local b = log_buf()
  log_set({ header, "" })
  show_log()
  local n, pending = 2, ""
  local function put(lines)
    if not vim.api.nvim_buf_is_valid(b) then
      return
    end
    vim.bo[b].modifiable = true
    vim.api.nvim_buf_set_lines(b, n, -1, false, lines)
    vim.bo[b].modifiable = false
    follow(win_of(b))
  end
  local function last_segment(str)
    return (str:gsub("\r+$", "")):match("[^\r]*$")
  end
  return {
    feed = function(chunk)
      pending = pending .. chunk
      local done = {}
      while true do
        local i = pending:find("\n", 1, true)
        if not i then
          break
        end
        done[#done + 1] = last_segment(pending:sub(1, i - 1))
        pending = pending:sub(i + 1)
      end
      local lines = vim.list_extend({}, done)
      local partial = last_segment(pending)
      if partial ~= "" then
        lines[#lines + 1] = partial -- linha em andamento (barra de progresso)
      end
      put(lines)
      n = n + #done
    end,
    finish = function(footer)
      local lines = {}
      if last_segment(pending) ~= "" then
        lines[#lines + 1] = last_segment(pending)
      end
      lines[#lines + 1] = ""
      lines[#lines + 1] = footer
      put(lines)
    end,
  }
end

--- encerra o monitor: MATA o processo e apaga o buffer (esconder só a janela
--- deixaria o arduino-cli segurando a porta → "Serial port busy").
--- Retorna true se a janela estava visível (usado pelo toggle).
local function close_monitor()
  local m = state.monitor
  state.monitor = nil
  if not m then
    return false
  end
  local visible = win_of(m.buf) ~= nil
  if m.job and m.job > 0 then
    pcall(vim.fn.jobstop, m.job)
  end
  if vim.api.nvim_buf_is_valid(m.buf) then
    pcall(vim.api.nvim_buf_delete, m.buf, { force = true })
  end
  return visible
end

local function monitor_title(port, baud)
  return ("  Serial %s @ %d   (Ctrl-\\ Ctrl-n → normal · q encerra · G segue o fim)"):format(port, baud)
end

--- monitor deste nvim ainda rodando (escondido ou visível)?
local function monitor_alive()
  local m = state.monitor
  if not m or not vim.api.nvim_buf_is_valid(m.buf) then
    return false
  end
  return vim.fn.jobwait({ m.job }, 0)[1] == -1
end

--- mostra o monitor que já existe (com tudo que chegou enquanto estava oculto)
local function show_monitor(focus)
  local m = state.monitor
  local cur = vim.api.nvim_get_current_win()
  local w = bottom_win(win_of(state.logbuf), "right")
  vim.api.nvim_win_set_buf(w, m.buf)
  vim.wo[w].winbar = monitor_title(m.port, m.baud)
  follow(w)
  if focus then
    vim.api.nvim_set_current_win(w)
    vim.cmd("startinsert")
  elseif vim.api.nvim_win_is_valid(cur) then
    vim.api.nvim_set_current_win(cur)
  end
end

local function sh(cmd)
  local r = vim.system(cmd, { text = true }):wait()
  return vim.trim(r.stdout or "")
end

--- quem está com a porta aberta (outro nvim, monitor órfão, picocom…)
local function port_holders(port)
  local pids = {}
  local out = vim.fn.executable("lsof") == 1 and sh({ "lsof", "-t", port }) or sh({ "fuser", port })
  for pid in out:gmatch("%d+") do
    pids[#pids + 1] = tonumber(pid)
  end
  local list = {}
  for _, pid in ipairs(pids) do
    local args = sh({ "ps", "-o", "args=", "-p", tostring(pid) })
    local ppid = tonumber(sh({ "ps", "-o", "ppid=", "-p", tostring(pid) }))
    local pargs = ppid and sh({ "ps", "-o", "args=", "-p", tostring(ppid) }) or ""
    local is_monitor = args:match("serial%-monitor") or args:match("arduino%-cli monitor")
    -- o dono "de verdade" é o `arduino-cli monitor` pai do serial-monitor
    local target = (args:match("serial%-monitor") and pargs:match("arduino%-cli monitor")) and ppid or pid
    list[#list + 1] = { pid = pid, target = target, args = args, is_monitor = is_monitor ~= nil }
  end
  return list
end

--- garante a porta livre: se outro monitor a segura, oferece assumir (em vez de "busy")
local function ensure_port_free(port, cb)
  local holders = port_holders(port)
  if #holders == 0 then
    return cb()
  end
  local others = vim.tbl_filter(function(h)
    return not h.is_monitor
  end, holders)
  if #others > 0 then
    return notify(
      ("Porta %s em uso por outro programa:\n  %s\nFeche-o e tente de novo."):format(port, others[1].args),
      L.WARN
    )
  end
  vim.ui.select({ "Assumir (encerra o outro monitor e abre aqui)", "Cancelar" }, {
    prompt = ("Já existe um monitor em %s (outra sessão do nvim?)"):format(port),
  }, function(choice)
    if not choice or choice == "Cancelar" then
      return
    end
    for _, h in ipairs(holders) do
      pcall(vim.uv.kill, h.target, "sigterm")
    end
    vim.defer_fn(cb, 500)
  end)
end

--- ESP32 + CP210x/CH340: depois de gravar, a linha serial às vezes fica presa em
--- nível baixo (o monitor vira uma enxurrada de "�"); só um reset da placa cura.
--- Detecta isso logo após abrir e reinicia a placa + reabre (até 3 tentativas).
local open_monitor
local function watch_flood(ctx, baud, focus, attempt, buf)
  vim.defer_fn(function()
    if not (state.monitor and state.monitor.buf == buf and vim.api.nvim_buf_is_valid(buf)) then
      return -- fechado pelo usuário nesse meio tempo
    end
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    local _, bad = text:gsub("\239\191\189", "") -- U+FFFD
    if bad < 100 then
      return
    end
    if attempt >= 3 then
      return notify(
        "Serial continua com lixo após 3 resets.\nAperte EN na placa; se repetir: cabo/porta USB ou capacitor 10µF entre EN e GND.",
        L.WARN,
        "arduino-serial"
      )
    end
    notify(("Serial com lixo (linha presa) — reiniciando a placa (%d/3)…"):format(attempt), L.WARN, "arduino-serial")
    close_monitor()
    M._reset_esp(ctx, function()
      open_monitor(ctx, baud, focus, attempt + 1)
    end)
  end, 1500)
end

function open_monitor(ctx, baud, focus, attempt)
  close_monitor()
  local cur = vim.api.nvim_get_current_win()
  local w = bottom_win(win_of(state.logbuf), "right")
  local job
  vim.api.nvim_win_call(w, function()
    vim.cmd("enew")
    job = vim.fn.jobstart(
      { cli(), "monitor", "--no-color", "--port", ctx.port, "--config", "baudrate=" .. baud },
      { term = true, cwd = ctx.dir }
    )
  end)
  local b = vim.api.nvim_win_get_buf(w)
  vim.bo[b].bufhidden = "hide" -- esconder a janela NÃO encerra: o monitor segue acumulando saída
  vim.wo[w].winbar = monitor_title(ctx.port, baud)
  follow(w)
  vim.keymap.set("n", "q", close_monitor, { buffer = b, silent = true, desc = "Fechar monitor" })
  state.monitor = { buf = b, job = job, port = ctx.port, baud = baud }
  if ctx.fqbn:match("^esp32:") then
    watch_flood(ctx, baud, focus, attempt or 1, b)
  end
  if focus then
    vim.api.nvim_set_current_win(w)
    vim.cmd("startinsert")
  elseif vim.api.nvim_win_is_valid(cur) then
    vim.api.nvim_set_current_win(cur)
  end
end

-- ───────────────────────── sketch ─────────────────────────

--- raiz do sketch. Buffer de arquivo: sketch.yaml acima dele, senão o dir do .ino.
--- Buffer sem arquivo (explorer, quickfix, monitor): o último sketch em que você
--- esteve; senão o cwd (se tiver .ino).
local function sketch_dir()
  local name = vim.api.nvim_buf_get_name(0)
  local is_file = vim.bo.buftype == "" and name ~= ""
  if not is_file and state.last_dir and vim.uv.fs_stat(state.last_dir) then
    return state.last_dir
  end
  local start = (is_file and vim.fs.dirname(name)) or vim.fn.getcwd()
  local root = vim.fs.root(start, { "sketch.yaml", "sketch.yml" })
  if root then
    return root
  end
  if is_file and name:match("%.ino$") then
    return vim.fs.dirname(name)
  end
  if #vim.fn.glob(start .. "/*.ino", false, true) > 0 then
    return start
  end
  notify("Nenhum sketch aqui — abra um .ino ou crie um com <leader>mn.", L.WARN)
end

local function sketch_name(dir)
  return vim.fs.basename(dir)
end

--- o arduino-cli exige <pasta>/<pasta>.ino
local function check_sketch(dir)
  if vim.uv.fs_stat(("%s/%s.ino"):format(dir, sketch_name(dir))) then
    return true
  end
  notify(
    ("O arduino-cli exige que o .ino tenha o nome da pasta:\n  %s/%s.ino\nRenomeie a pasta ou o arquivo."):format(
      dir,
      sketch_name(dir)
    ),
    L.ERROR
  )
  return false
end

--- salva os buffers modificados do sketch (o arduino-cli lê o ARQUIVO, não o buffer;
--- sem isso um `#include` recém-digitado não entra no build nem no banco do clangd)
local function save_sketch(dir)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].modified and vim.bo[b].buftype == "" then
      local n = vim.api.nvim_buf_get_name(b)
      if n ~= "" and vim.startswith(n, dir .. "/") then
        vim.api.nvim_buf_call(b, function()
          vim.cmd("silent! update")
        end)
      end
    end
  end
end

--- "assinatura" dos #include do buffer (mudou → o banco do clangd precisa regenerar)
local function includes_hash(buf)
  local inc = {}
  for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if l:match("^%s*#%s*include") then
      inc[#inc + 1] = vim.trim(l)
    end
  end
  return table.concat(inc, "\n")
end

-- sketch.yaml: só mexemos em chaves `default_*` (resto do arquivo é preservado)
local function yaml_get(dir, key)
  local s = read(dir .. "/sketch.yaml")
  if not s then
    return nil
  end
  for line in s:gmatch("[^\r\n]+") do
    local v = line:match("^" .. key .. ":%s*(.-)%s*$")
    if v and v ~= "" then
      return (v:gsub("^[\"'](.*)[\"']$", "%1"))
    end
  end
end

local function yaml_set(dir, key, val)
  local path = dir .. "/sketch.yaml"
  local lines, done = {}, false
  local s = read(path)
  if s then
    for line in s:gmatch("[^\r\n]+") do
      if line:match("^" .. key .. ":") then
        line, done = ("%s: %s"):format(key, val), true
      end
      lines[#lines + 1] = line
    end
  end
  if not done then
    lines[#lines + 1] = ("%s: %s"):format(key, val)
  end
  write(path, table.concat(lines, "\n") .. "\n")
end

local function build_path(dir)
  local id = vim.fn.sha256(dir):sub(1, 10)
  local p = ("%s/arduino/%s-%s"):format(vim.fn.stdpath("cache"), sketch_name(dir), id)
  vim.fn.mkdir(p, "p")
  return p
end

-- FQBN = pacote:arch:placa[:opt=val,opt=val]
local function split_fqbn(fqbn)
  local parts = vim.split(fqbn, ":", { plain = true })
  local base = table.concat(parts, ":", 1, math.min(3, #parts))
  local opts = {}
  for kv in (parts[4] or ""):gmatch("[^,]+") do
    local k, v = kv:match("^(.-)=(.*)$")
    if k then
      opts[k] = v
    end
  end
  return base, opts
end

local function join_fqbn(base, opts)
  local keys = vim.tbl_keys(opts)
  table.sort(keys)
  if #keys == 0 then
    return base
  end
  local kv = vim.tbl_map(function(k)
    return k .. "=" .. opts[k]
  end, keys)
  return base .. ":" .. table.concat(kv, ",")
end

local function detect_baud(dir)
  for _, f in ipairs(vim.fn.glob(dir .. "/*.ino", false, true)) do
    local b = (read(f) or ""):match("Serial%d?%.begin%s*%(%s*(%d+)")
    if b then
      return tonumber(b)
    end
  end
  return 115200
end

-- ───────────────────────── LSP (clangd) ─────────────────────────

local REMOVE = {
  "-mlongcalls", "-mlong-calls", "-mfix-esp32-psram-cache-issue", "-mfix-esp32-psram-cache-strategy=*",
  "-mdisable-hardware-atomics", "-fstrict-volatile-bitfields", "-fno-tree-switch-conversion",
  "-fno-shrink-wrap", "-freorder-blocks", "-mtext-section-literals", "-mfix-esp32-*",
}

--- globs p/ `clangd --query-driver` (toolchains dos cores nos dois SOs)
function M.query_driver()
  local h = vim.fn.expand("~")
  return table.concat({
    h .. "/.arduino15/packages/**/bin/*",
    h .. "/Library/Arduino15/packages/**/bin/*",
  }, ",")
end

local TPL = 4 -- versão do template: mudou → .clangd antigos são regenerados sozinhos

--- incs = pastas `src` das bibliotecas que VOCÊ instalou (~/Arduino/libraries):
--- assim `#include <` no .ino já sugere os headers delas, antes de usar a primeira vez.
local function clangd_text(dir, fqbn, bp, incs)
  local t = {
    "# Gerado por nvim/lua/arduino — não edite (regenere com <leader>mg).",
    "# fqbn: " .. fqbn,
    "# tpl: " .. TPL,
    "CompileFlags:",
    "  CompilationDatabase: " .. bp,
    "  Remove: [" .. table.concat(REMOVE, ", ") .. "]",
    '  Add: ["-D__GLIBC_USE(x)=0"]',
    "---",
    "# O arduino-builder injeta `#include <Arduino.h>` no .cpp gerado, mas o clangd lê o .ino",
    "# direto — sem isso Serial/pinMode/OUTPUT ficam 'undeclared' em sketches sem libs.",
    "# Os -I extras são as bibliotecas do usuário (completar `#include <...>`).",
    "If:",
    "  PathMatch: .*\\.ino",
    "CompileFlags:",
    "  Add:",
    "    - -include",
    "    - Arduino.h",
  }
  for _, inc in ipairs(incs or {}) do
    t[#t + 1] = ('    - "-I%s"'):format(inc)
  end
  t[#t + 1] = ""
  return table.concat(t, "\n")
end

--- pastas de include das bibliotecas do usuário compatíveis com a placa
local function lib_includes(fqbn, cb)
  local base = split_fqbn(fqbn)
  run({ "lib", "list", "--all", "--fqbn", base, "--format", "json" }, function(res)
    local ok, data = pcall(vim.json.decode, res.stdout or "")
    local incs, seen = {}, {}
    if ok and data and data.installed_libraries then
      for _, item in ipairs(data.installed_libraries) do
        local lib = item.library or {}
        local d = lib.source_dir
        -- só as bibliotecas do USUÁRIO: as ~44 do core (WiFi, BLE…) enterrariam as suas na
        -- lista (o clangd corta em N itens, em ordem alfabética)
        if d and lib.location ~= "platform" and not seen[d] then
          seen[d] = true
          incs[#incs + 1] = d
        end
      end
    end
    table.sort(incs)
    cb(incs)
  end)
end

local CLANGD_MARKERS = { ".clangd", ".clang-tidy", ".clang-format", "compile_commands.json", "compile_flags.txt", "configure.ac", ".git" }

--- root_dir do clangd (plugins/c.lua). Em .ino só inicia com `.clangd` gerado:
--- sem ele o clangd cai no comando "fallback" (`clang -- x.ino`), não monta o
--- AST e o nvim enche de "clangd: -32001: invalid AST".
function M.clangd_root_dir(bufnr, on_dir)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if vim.bo[bufnr].filetype == "arduino" then
    local dir = vim.fs.dirname(name)
    if vim.uv.fs_stat(dir .. "/.clangd") then
      on_dir(dir)
    end
    return
  end
  on_dir(vim.fs.root(bufnr, CLANGD_MARKERS) or vim.fs.dirname(name))
end

--- depois de gerar o .clangd: reinicia o clangd (se já roda) ou o inicia nos
--- buffers .ino abertos daquele sketch (o enable do LSP dispara no FileType)
local function ensure_lsp(dir, changed)
  local running = false
  for _, c in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
    if c.root_dir == dir then
      running = true
    end
  end
  if running then
    if changed then
      pcall(vim.cmd, "lsp restart clangd")
    end
    return
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local n = vim.api.nvim_buf_get_name(b)
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype == "arduino" and vim.fs.dirname(n) == dir then
      vim.api.nvim_exec_autocmds("FileType", { buffer = b, modeline = false })
    end
  end
end

--- gera compile_commands (rápido, sem compilar) + .clangd e reinicia o clangd
function M.lsp(opts)
  opts = opts or {}
  local dir = opts.dir or sketch_dir()
  if not dir or not check_sketch(dir) then
    return
  end
  save_sketch(dir)
  local fqbn = yaml_get(dir, "default_fqbn")
  if not fqbn then
    return M.pick_board(function()
      M.lsp({ dir = dir, silent = opts.silent, restart = opts.restart })
    end)
  end
  local bp = build_path(dir)
  run({ "compile", "--only-compilation-database", "--no-color", "--fqbn", fqbn, "--build-path", bp, dir }, function(res)
    if res.code ~= 0 then
      log_set(vim.split((res.stdout or "") .. (res.stderr or ""), "\n"))
      show_log()
      return notify("Falha ao gerar o banco de compilação (veja o log).", L.ERROR)
    end
    lib_includes(fqbn, function(incs)
      local text = clangd_text(dir, fqbn, bp, incs)
      local changed = read(dir .. "/.clangd") ~= text
      if changed then
        write(dir .. "/.clangd", text)
      end
      ensure_lsp(dir, changed or opts.restart)
      if not opts.silent then
        notify(("LSP pronto para %s (%d bibliotecas)"):format(fqbn, #incs), L.INFO)
      end
    end)
  end)
end

--- ao abrir um .ino: se o .clangd não existe / está desatualizado, regenera
function M.auto_lsp(dir)
  local fqbn = yaml_get(dir, "default_fqbn")
  if not fqbn or not check_sketch(dir) then
    return
  end
  -- regenera se faltar, se for de outra placa ou de uma versão antiga do template
  local cur = read(dir .. "/.clangd") or ""
  if cur:match("# fqbn: ([^\n]+)") ~= fqbn or cur:match("# tpl: (%d+)") ~= tostring(TPL) then
    M.lsp({ dir = dir, silent = true })
  end
end

-- ───────────────────────── pickers ─────────────────────────

local function set_fqbn(dir, fqbn)
  yaml_set(dir, "default_fqbn", fqbn)
end

function M.pick_port(cb)
  local dir = sketch_dir()
  if not dir then
    return
  end
  json({ "board", "list", "--format", "json" }, function(data)
    local items = {}
    for _, d in ipairs(data.detected_ports or data) do
      local p = d.port or {}
      local addr = p.address or ""
      -- macOS lista portas de sistema (Bluetooth, debug-console) — ruído
      if p.protocol == "serial" and not addr:match("[Bb]luetooth") and not addr:match("debug%-console") then
        local b = d.matching_boards and d.matching_boards[1]
        items[#items + 1] = { port = addr, board = b, label = addr .. (b and ("  —  " .. b.name) or "  —  placa desconhecida") }
      end
    end
    if #items == 0 then
      return notify(
        "Nenhuma porta serial detectada.\n"
          .. "  • cabo USB é de dados (não só carga)?\n"
          .. "  • Linux: grupo uucp/dialout e `brltty` (rouba CH340/CP210x) — veja o manual\n"
          .. "  • macOS: driver CH340/CP210x p/ clones",
        L.WARN
      )
    end
    vim.ui.select(items, {
      prompt = "Porta serial",
      format_item = function(i)
        return i.label
      end,
    }, function(choice)
      if not choice then
        return
      end
      yaml_set(dir, "default_port", choice.port)
      yaml_set(dir, "default_protocol", "serial")
      -- placa reconhecida (ex.: Uno) e nenhuma definida ainda → já grava
      if choice.board and choice.board.fqbn and not yaml_get(dir, "default_fqbn") then
        set_fqbn(dir, choice.board.fqbn)
      end
      notify("Porta: " .. choice.port)
      if cb then
        cb(choice.port)
      end
    end)
  end)
end

function M.pick_board(cb)
  local dir = sketch_dir()
  if not dir then
    return
  end
  json({ "board", "listall", "--format", "json" }, function(data)
    local items = {}
    for _, b in ipairs(data.boards or {}) do
      if b.fqbn and not b.hidden then
        items[#items + 1] = b
      end
    end
    if #items == 0 then
      return notify(
        "Nenhuma placa instalada. Instale um core, ex.:\n  arduino-cli core update-index && arduino-cli core install esp32:esp32\n(veja o manual p/ a URL do ESP32)",
        L.WARN
      )
    end
    table.sort(items, function(a, b)
      return a.name < b.name
    end)
    vim.ui.select(items, {
      prompt = "Placa",
      format_item = function(b)
        return ("%s  (%s)"):format(b.name, b.fqbn)
      end,
    }, function(choice)
      if not choice then
        return
      end
      set_fqbn(dir, choice.fqbn)
      notify("Placa: " .. choice.name .. "\n" .. choice.fqbn)
      M.lsp({ dir = dir, silent = true })
      if cb then
        cb(choice.fqbn)
      end
    end)
  end)
end

--- opções da placa (Partition Scheme, PSRAM, Upload Speed…) → vão no FQBN
function M.pick_options()
  local dir = sketch_dir()
  if not dir then
    return
  end
  local fqbn = yaml_get(dir, "default_fqbn")
  if not fqbn then
    return M.pick_board(M.pick_options)
  end
  local base, cur = split_fqbn(fqbn)
  json({ "board", "details", "--fqbn", base, "--format", "json" }, function(data)
    local menus = data.config_options or {}
    if #menus == 0 then
      return notify("Esta placa não tem opções configuráveis.")
    end
    local function current_label(m)
      local want = cur[m.option]
      for _, v in ipairs(m.values) do
        if (want and v.value == want) or (not want and v.selected) then
          return v.value_label
        end
      end
      return "?"
    end
    vim.ui.select(menus, {
      prompt = "Opção da placa",
      format_item = function(m)
        return ("%s: %s"):format(m.option_label, current_label(m))
      end,
    }, function(menu)
      if not menu then
        return
      end
      vim.ui.select(menu.values, {
        prompt = menu.option_label,
        format_item = function(v)
          return v.value_label
        end,
      }, function(v)
        if not v then
          return
        end
        cur[menu.option] = v.value
        local new = join_fqbn(base, cur)
        set_fqbn(dir, new)
        notify(("%s = %s\n%s"):format(menu.option_label, v.value_label, new))
        M.lsp({ dir = dir, silent = true })
      end)
    end)
  end)
end

function M.lib_search()
  vim.ui.input({ prompt = "Buscar biblioteca: " }, function(q)
    if not q or q == "" then
      return
    end
    json({ "lib", "search", q, "--format", "json" }, function(data)
      local libs = data.libraries or {}
      if #libs == 0 then
        return notify("Nada encontrado para '" .. q .. "'.")
      end
      vim.ui.select(libs, {
        prompt = "Instalar biblioteca",
        format_item = function(l)
          local latest = l.latest or {}
          local s = latest.sentence or ""
          return ("%s  %s  %s"):format(l.name, latest.version or "", s)
        end,
      }, function(l)
        if not l then
          return
        end
        notify("Instalando " .. l.name .. "…", L.INFO, "arduino-lib")
        run({ "lib", "install", l.name }, function(res)
          if res.code ~= 0 then
            return notify("Falha:\n" .. (res.stderr or ""), L.ERROR, "arduino-lib")
          end
          local out = (res.stdout or "") .. (res.stderr or "")
          local ver = out:match("Installed [^\n]+") or out:match("Already installed [^\n]+")
          if out:match("Already installed") and not out:match("Installed ") then
            notify(l.name .. " já estava instalada (nada mudou).\n" .. (ver or ""), L.INFO, "arduino-lib")
          else
            notify(l.name .. " instalada em ~/Arduino/libraries.\nLSP atualizado: já aparece em `#include <`.", L.INFO, "arduino-lib")
          end
          M.lsp({ silent = true, restart = true })
        end)
      end)
    end)
  end)
end

-- ───────────────────────── contexto (placa/porta) ─────────────────────────

--- garante sketch + fqbn (+ porta) antes de agir; pergunta o que faltar
local function with_ctx(need_port, cb)
  local dir = sketch_dir()
  if not dir or not check_sketch(dir) then
    return
  end
  local fqbn = yaml_get(dir, "default_fqbn")
  if not fqbn then
    return M.pick_board(function()
      with_ctx(need_port, cb)
    end)
  end
  local port = yaml_get(dir, "default_port")
  if need_port and not port then
    return M.pick_port(function()
      with_ctx(need_port, cb)
    end)
  end
  cb({ dir = dir, fqbn = fqbn, port = port, bp = build_path(dir) })
end

-- ───────────────────────── compilar / gravar ─────────────────────────

local function parse_errors(lines)
  local items = {}
  for _, l in ipairs(lines) do
    local file, lnum, col, kind, msg = l:match("^(/[^:]+):(%d+):(%d+): ([%a ]-):%s*(.*)$")
    if file then
      local t = kind:match("error") and "E" or kind:match("warning") and "W" or "I"
      items[#items + 1] = { filename = file, lnum = tonumber(lnum), col = tonumber(col), type = t, text = msg }
    end
  end
  return items
end

--- compila (e grava se upload). O log abre ao vivo; ao gravar com sucesso o
--- monitor serial abre sozinho ao lado do log.
local function run_compile(ctx, upload)
  do
    save_sketch(ctx.dir)
    local args = { "compile", "--no-color", "--warnings", "default", "--fqbn", ctx.fqbn, "--build-path", ctx.bp }
    if upload then
      vim.list_extend(args, { "--upload", "--port", ctx.port })
    end
    args[#args + 1] = ctx.dir
    local stream = log_stream(
      "$ arduino-cli " .. table.concat(vim.list_slice(args, 1, #args - 1), " ") .. " " .. vim.fn.fnamemodify(ctx.dir, ":~")
    )
    local raw = {}
    local what = upload and "Compilando e gravando" or "Compilando"
    notify(("%s %s…"):format(what, sketch_name(ctx.dir)), L.INFO, "arduino-build")
    run(args, function(res)
      local text = table.concat(raw)
      local lines = vim.split((text:gsub("\r", "\n")), "\n")
      local items = parse_errors(lines)
      vim.fn.setqflist({}, " ", { title = "arduino-cli", items = items })
      if res.code == 0 then
        stream.finish(upload and "✔ gravado" or "✔ compilado")
        local sizes = {}
        for _, l in ipairs(lines) do
          if l:match("^Sketch uses") or l:match("^Global variables") then
            sizes[#sizes + 1] = l
          end
        end
        notify((upload and "Gravado ✔\n" or "Compilado ✔\n") .. table.concat(sizes, "\n"), L.INFO, "arduino-build")
        if upload then
          open_monitor(ctx, vim.g.arduino_baud or detect_baud(ctx.dir), false)
        end
      else
        stream.finish(("✘ falhou (código %s)"):format(res.code))
        notify(
          (upload and "Falha ao gravar" or "Falha ao compilar") .. " ✘\nEnter no log pula p/ o erro · :copen lista",
          L.ERROR,
          "arduino-build"
        )
      end
    end, {
      cwd = ctx.dir,
      on_output = function(chunk)
        raw[#raw + 1] = chunk
        stream.feed(chunk)
      end,
    })
  end
end

function M.compile(upload)
  with_ctx(upload, function(ctx)
    if upload then
      close_monitor() -- o monitor deste nvim segura a porta e impediria o upload
      return ensure_port_free(ctx.port, function()
        run_compile(ctx, true)
      end)
    end
    run_compile(ctx, false)
  end)
end

--- mostra/oculta o painel de log (o conteúdo é do último build)
function M.log()
  local w = win_of(state.logbuf)
  if w then
    return vim.api.nvim_win_close(w, false)
  end
  if not state.logbuf or vim.api.nvim_buf_line_count(log_buf()) <= 1 then
    return notify("Sem log ainda — compile primeiro (<leader>mc).")
  end
  show_log()
end

--- Enter no log: abre o arquivo:linha:coluna da linha sob o cursor
function M.log_jump()
  local line = vim.api.nvim_get_current_line()
  local file, lnum, col = line:match("(/[^:%s]+):(%d+):(%d+)")
  if not file then
    file, lnum = line:match("(/[^:%s]+):(%d+)")
  end
  if not file or vim.fn.filereadable(file) == 0 then
    return
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].buftype == "" and w ~= vim.api.nvim_get_current_win() then
      vim.api.nvim_set_current_win(w)
      break
    end
  end
  vim.cmd.edit(vim.fn.fnameescape(file))
  pcall(vim.api.nvim_win_set_cursor, 0, { tonumber(lnum), math.max((tonumber(col) or 1) - 1, 0) })
end

-- ───────────────────────── monitor serial ─────────────────────────

--- <leader>mm: mostra/oculta o monitor SEM encerrá-lo (a saída continua acumulando
--- escondida). Se já existe um monitor em outra sessão do nvim, oferece assumir.
--- `q` dentro do monitor encerra de vez. `:ArduinoMonitor 9600` reabre em outro baud.
function M.monitor(baud)
  local new_baud = tonumber(baud)
  if monitor_alive() and (not new_baud or new_baud == state.monitor.baud) then
    local w = win_of(state.monitor.buf)
    if w then
      vim.api.nvim_win_close(w, false)
      return notify("Monitor oculto — segue rodando e guardando a saída.\n<leader>mm mostra · q (dentro dele) encerra.")
    end
    return show_monitor(true)
  end
  close_monitor() -- limpa monitor que já terminou ou que vai trocar de baud
  with_ctx(true, function(ctx)
    ensure_port_free(ctx.port, function()
      open_monitor(ctx, new_baud or vim.g.arduino_baud or detect_baud(ctx.dir), true)
    end)
  end)
end

-- ───────────────────────── backtrace do ESP32 ─────────────────────────

local function data_dir(cb)
  if state.data_dir then
    return cb(state.data_dir)
  end
  run({ "config", "get", "directories.data" }, function(res)
    state.data_dir = vim.trim(res.stdout or "")
    cb(state.data_dir)
  end)
end

--- reinicia o ESP32 (pulso em EN via RTS) usando o esptool do próprio core
function M._reset_esp(ctx, cb)
  data_dir(function(dd)
    local found = vim.fn.glob(dd .. "/packages/esp32/tools/esptool_py/*/esptool", false, true)
    if #found == 0 then
      found = vim.fn.glob(dd .. "/packages/esp32/tools/esptool_py/*/esptool.py", false, true)
    end
    table.sort(found)
    local tool = found[#found]
    if not tool then
      return cb()
    end
    vim.system({ tool, "--port", ctx.port, "--after", "hard-reset", "read-mac" }, { text = true }, function()
      vim.defer_fn(cb, 300)
    end)
  end)
end

local function addr2line_for(fqbn, dd)
  local board = fqbn:match("^[^:]+:[^:]+:([^:,]+)") or ""
  local prefix = "xtensa-esp32-elf"
  if board:match("c[2356]") or board:match("h2") or board:match("p4") then
    prefix = "riscv32-esp-elf"
  elseif board:match("s3") then
    prefix = "xtensa-esp32s3-elf"
  elseif board:match("s2") then
    prefix = "xtensa-esp32s2-elf"
  end
  local found = vim.fn.glob(("%s/packages/esp32/tools/*/*/bin/%s-addr2line"):format(dd, prefix), false, true)
  table.sort(found)
  return found[#found]
end

--- :ArduinoDecode — seleção visual, ou o registro + (clipboard) / "
function M.decode(range_text)
  with_ctx(false, function(ctx)
    local elf = ("%s/%s.ino.elf"):format(ctx.bp, sketch_name(ctx.dir))
    if not vim.uv.fs_stat(elf) then
      return notify("Sem .elf — compile antes (<leader>mc).", L.WARN)
    end
    local text = range_text
    if not text or text == "" then
      text = vim.fn.getreg("+")
      if text == "" then
        text = vim.fn.getreg('"')
      end
    end
    local addrs, seen = {}, {}
    -- só endereços de código (0x4...); 0x3ffb... são ponteiros de pilha/dados
    for a in text:gmatch("0x4%x%x%x%x%x%x%x") do
      if not seen[a] then
        seen[a] = true
        addrs[#addrs + 1] = a
      end
    end
    if #addrs == 0 then
      return notify("Nenhum endereço 0x4xxxxxxx no texto (copie a linha 'Backtrace:' do monitor).", L.WARN)
    end
    data_dir(function(dd)
      local tool = addr2line_for(ctx.fqbn, dd)
      if not tool then
        return notify("addr2line do core ESP32 não encontrado em " .. dd, L.ERROR)
      end
      local cmd = { tool, "-pfiaC", "-e", elf }
      vim.list_extend(cmd, addrs)
      vim.system(cmd, { text = true }, function(res)
        vim.schedule(function()
          local items = {}
          for line in (res.stdout or ""):gmatch("[^\n]+") do
            local addr, fn, file, lnum = line:match("^(0x%x+):%s*(.-) at (.-):(%d+)")
            if addr and file ~= "??" then
              items[#items + 1] = { filename = file, lnum = tonumber(lnum), text = ("%s  %s"):format(addr, fn) }
            end
          end
          if #items == 0 then
            return notify("Não consegui mapear os endereços:\n" .. (res.stdout or res.stderr or ""), L.WARN)
          end
          vim.fn.setqflist({}, " ", { title = "backtrace ESP32", items = items })
          vim.cmd("botright copen " .. math.min(#items + 1, 12))
        end)
      end)
    end)
  end)
end

-- ───────────────────────── info / novo sketch ─────────────────────────

function M.info()
  local dir = sketch_dir()
  if not dir then
    return
  end
  run({ "version", "--format", "json" }, function(res)
    local ok, v = pcall(vim.json.decode, res.stdout or "")
    notify(table.concat({
      "sketch : " .. dir,
      "placa  : " .. (yaml_get(dir, "default_fqbn") or "— (<leader>mb)"),
      "porta  : " .. (yaml_get(dir, "default_port") or "— (<leader>mp)"),
      "baud   : " .. (vim.g.arduino_baud or detect_baud(dir)),
      "cli    : " .. (ok and v.VersionString or "?") .. "  (" .. (cli() or "?") .. ")",
      "build  : " .. build_path(dir),
    }, "\n"))
  end)
end

function M.new(name)
  if not name or name == "" then
    return vim.ui.input({ prompt = "Nome do novo sketch: " }, function(n)
      if n and n ~= "" then
        M.new(n)
      end
    end)
  end
  run({ "sketch", "new", name }, function(res)
    if res.code ~= 0 then
      return notify("Falha:\n" .. (res.stderr or ""), L.ERROR)
    end
    local ino = ("%s/%s/%s.ino"):format(vim.fn.getcwd(), name, name)
    vim.cmd.edit(vim.fn.fnameescape(ino))
    vim.schedule(M.pick_board)
  end, { cwd = vim.fn.getcwd() })
end

-- ───────────────────────── setup ─────────────────────────

function M.setup()
  local cmd = vim.api.nvim_create_user_command
  cmd("ArduinoCompile", function() M.compile(false) end, { desc = "Compilar sketch" })
  cmd("ArduinoUpload", function() M.compile(true) end, { desc = "Compilar e gravar" })
  cmd("ArduinoMonitor", function(o) M.monitor(o.args) end, { nargs = "?", desc = "Monitor serial (toggle) [baud]" })
  cmd("ArduinoPort", function() M.pick_port() end, { desc = "Escolher porta" })
  cmd("ArduinoBoard", function() M.pick_board() end, { desc = "Escolher placa" })
  cmd("ArduinoOptions", function() M.pick_options() end, { desc = "Opções da placa" })
  cmd("ArduinoLib", function() M.lib_search() end, { desc = "Buscar/instalar biblioteca" })
  cmd("ArduinoLsp", function() M.lsp({ restart = true }) end, { desc = "Regenerar LSP (.clangd)" })
  cmd("ArduinoLog", function() M.log() end, { desc = "Mostrar/ocultar log do build" })
  cmd("ArduinoInfo", function() M.info() end, { desc = "Estado do sketch" })
  cmd("ArduinoNew", function(o) M.new(o.args) end, { nargs = "?", desc = "Novo sketch" })
  cmd("ArduinoDecode", function(o)
    local text
    if o.range > 0 then
      text = table.concat(vim.api.nvim_buf_get_lines(0, o.line1 - 1, o.line2, false), "\n")
    end
    M.decode(text)
  end, { range = true, desc = "Decodificar backtrace do ESP32" })

  -- Atalhos GLOBAIS (o grupo aparece no which-key em qualquer buffer); sem
  -- sketch por perto, cada ação avisa em vez de falhar.
  local function map(lhs, rhs, desc, mode)
    vim.keymap.set(mode or "n", "<leader>m" .. lhs, rhs, { desc = desc })
  end
  map("c", function() M.compile(false) end, "Compilar")
  map("u", function() M.compile(true) end, "Compilar + gravar")
  map("m", function() M.monitor() end, "Monitor serial (toggle)")
  map("p", function() M.pick_port() end, "Porta")
  map("b", function() M.pick_board() end, "Placa")
  map("o", function() M.pick_options() end, "Opções da placa")
  map("l", function() M.lib_search() end, "Bibliotecas")
  map("g", function() M.lsp({ restart = true }) end, "Regenerar LSP")
  map("i", function() M.info() end, "Info do sketch")
  map("L", function() M.log() end, "Log do build (mostra/oculta)")
  map("n", function() M.new() end, "Novo sketch")
  map("d", ":ArduinoDecode<cr>", "Decodificar backtrace (seleção)", "x")
  map("d", function() M.decode() end, "Decodificar backtrace (clipboard)")
  local ok, wk = pcall(require, "which-key")
  if ok then
    wk.add({ { "<leader>m", group = "arduino/esp32", mode = { "n", "x" }, icon = "" } })
  end

  local group = vim.api.nvim_create_augroup("arduino_nvim", { clear = true })
  -- lembra o último sketch (p/ agir a partir do explorer/quickfix/monitor)
  vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
    group = group,
    pattern = { "*.ino", "arduino" },
    callback = function(ev)
      local name = vim.api.nvim_buf_get_name(ev.buf)
      if name ~= "" and vim.bo[ev.buf].buftype == "" then
        state.last_dir = vim.fs.root(name, { "sketch.yaml", "sketch.yml" }) or vim.fs.dirname(name)
      end
    end,
  })
  -- salvou mudando os #include → regenera o banco (senão `#include <Lib.h>` fica "not found")
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.ino",
    callback = function(ev)
      local dir = vim.fs.root(ev.buf, { "sketch.yaml", "sketch.yml" }) or vim.fs.dirname(ev.file)
      local h = includes_hash(ev.buf)
      local before = state.inc[ev.file]
      state.inc[ev.file] = h
      if before ~= nil and before ~= h and vim.uv.fs_stat(dir .. "/.clangd") then
        M.lsp({ dir = dir, silent = true, restart = true })
      end
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "arduino",
    callback = function(ev)
      state.inc[vim.api.nvim_buf_get_name(ev.buf)] = includes_hash(ev.buf)
      local dir = vim.fs.root(ev.buf, { "sketch.yaml", "sketch.yml" })
      if dir then
        vim.schedule(function()
          M.auto_lsp(dir)
        end)
      end
    end,
  })
end

return M
