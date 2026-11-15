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
local state = { monitor = nil, reopen = false, log = {}, data_dir = nil }

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

--- roda o arduino-cli sem bloquear; cb(res) no loop principal
local function run(args, cb, opts)
  local bin = cli()
  if not bin then
    return
  end
  local cmd = { bin }
  vim.list_extend(cmd, args)
  vim.system(cmd, { text = true, cwd = opts and opts.cwd }, function(res)
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

-- ───────────────────────── sketch ─────────────────────────

--- raiz do sketch: dir com sketch.yaml acima do buffer, senão dir do .ino
local function sketch_dir()
  local name = vim.api.nvim_buf_get_name(0)
  local start = (name ~= "" and vim.fs.dirname(name)) or vim.fn.getcwd()
  local root = vim.fs.root(start, { "sketch.yaml", "sketch.yml" })
  if root then
    return root
  end
  if name:match("%.ino$") then
    return vim.fs.dirname(name)
  end
  if #vim.fn.glob(start .. "/*.ino", false, true) > 0 then
    return start
  end
  notify("Nenhum sketch aqui (abra um .ino ou rode :ArduinoNew <nome>).", L.WARN)
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

local function clangd_text(dir, fqbn, bp)
  return table.concat({
    "# Gerado por nvim/lua/arduino — não edite (regenere com <leader>mg).",
    "# fqbn: " .. fqbn,
    "CompileFlags:",
    "  CompilationDatabase: " .. bp,
    "  Remove: [" .. table.concat(REMOVE, ", ") .. "]",
    '  Add: ["-D__GLIBC_USE(x)=0"]',
    "",
  }, "\n")
end

--- gera compile_commands (rápido, sem compilar) + .clangd e reinicia o clangd
function M.lsp(opts)
  opts = opts or {}
  local dir = opts.dir or sketch_dir()
  if not dir or not check_sketch(dir) then
    return
  end
  local fqbn = yaml_get(dir, "default_fqbn")
  if not fqbn then
    return M.pick_board(function()
      M.lsp({ dir = dir, silent = opts.silent })
    end)
  end
  local bp = build_path(dir)
  run({ "compile", "--only-compilation-database", "--no-color", "--fqbn", fqbn, "--build-path", bp, dir }, function(res)
    if res.code ~= 0 then
      state.log = vim.split((res.stdout or "") .. (res.stderr or ""), "\n")
      return notify("Falha ao gerar o banco de compilação (veja :ArduinoLog).", L.ERROR)
    end
    local text = clangd_text(dir, fqbn, bp)
    if read(dir .. "/.clangd") ~= text then
      write(dir .. "/.clangd", text)
      pcall(vim.cmd, "lsp restart clangd")
    end
    if not opts.silent then
      notify("LSP pronto para " .. fqbn, L.INFO)
    end
  end)
end

--- ao abrir um .ino: se o .clangd não existe / é de outra placa, regenera
function M.auto_lsp(dir)
  local fqbn = yaml_get(dir, "default_fqbn")
  if not fqbn or not check_sketch(dir) then
    return
  end
  local cur = read(dir .. "/.clangd") or ""
  if cur:match("# fqbn: ([^\n]+)") ~= fqbn then
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
          notify(l.name .. " instalada.", L.INFO, "arduino-lib")
          M.lsp({ silent = true })
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

local function close_monitor()
  local m = state.monitor
  if m and m.win and vim.api.nvim_win_is_valid(m.win) then
    pcall(function()
      m:close()
    end)
    state.monitor = nil
    return true
  end
  state.monitor = nil
  return false
end

function M.compile(upload)
  with_ctx(upload, function(ctx)
    local was_open = false
    if upload then
      was_open = close_monitor() -- porta ocupada pelo monitor impede o upload
    end
    local args = { "compile", "--no-color", "--warnings", "default", "--fqbn", ctx.fqbn, "--build-path", ctx.bp }
    if upload then
      vim.list_extend(args, { "--upload", "--port", ctx.port })
    end
    args[#args + 1] = ctx.dir
    local what = upload and "Compilando e gravando" or "Compilando"
    notify(("%s %s…"):format(what, sketch_name(ctx.dir)), L.INFO, "arduino-build")
    run(args, function(res)
      local lines = vim.split((res.stdout or "") .. "\n" .. (res.stderr or ""), "\n")
      state.log = lines
      local items = parse_errors(lines)
      vim.fn.setqflist({}, " ", { title = "arduino-cli", items = items })
      if res.code == 0 then
        local sizes = {}
        for _, l in ipairs(lines) do
          if l:match("^Sketch uses") or l:match("^Global variables") then
            sizes[#sizes + 1] = l
          end
        end
        notify((upload and "Gravado ✔\n" or "Compilado ✔\n") .. table.concat(sizes, "\n"), L.INFO, "arduino-build")
        if #items > 0 then
          vim.cmd("botright copen 8 | wincmd p")
        end
        if was_open then
          M.monitor()
        end
      else
        notify((upload and "Falha ao gravar" or "Falha ao compilar") .. " ✘", L.ERROR, "arduino-build")
        if #items > 0 then
          vim.cmd("botright copen 10")
        else
          M.log() -- erro de linker/upload não tem arquivo:linha → mostra o log cru
        end
      end
    end, { cwd = ctx.dir })
  end)
end

function M.log()
  if #state.log == 0 then
    return notify("Sem log ainda.")
  end
  vim.cmd("botright 14new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype, vim.bo[buf].bufhidden, vim.bo[buf].swapfile = "nofile", "wipe", false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, state.log)
  vim.api.nvim_buf_set_name(buf, "arduino-cli://log")
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
end

-- ───────────────────────── monitor serial ─────────────────────────

function M.monitor(baud)
  if close_monitor() then
    return -- toggle
  end
  with_ctx(true, function(ctx)
    baud = tonumber(baud) or vim.g.arduino_baud or detect_baud(ctx.dir)
    local cmd = { cli(), "monitor", "--no-color", "--port", ctx.port, "--config", "baudrate=" .. baud }
    local ok, Snacks = pcall(require, "snacks")
    if ok and Snacks.terminal then
      state.monitor = Snacks.terminal.open(cmd, {
        cwd = ctx.dir,
        interactive = true,
        auto_close = false,
        win = { position = "bottom", height = 0.3, title = (" Serial %s @ %d "):format(ctx.port, baud), title_pos = "center" },
      })
    else
      vim.cmd("botright 12split | terminal " .. table.concat(vim.tbl_map(vim.fn.shellescape, cmd), " "))
      vim.cmd("startinsert")
    end
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
  cmd("ArduinoLsp", function() M.lsp() end, { desc = "Regenerar LSP (.clangd)" })
  cmd("ArduinoLog", function() M.log() end, { desc = "Último log do arduino-cli" })
  cmd("ArduinoInfo", function() M.info() end, { desc = "Estado do sketch" })
  cmd("ArduinoNew", function(o) M.new(o.args) end, { nargs = "?", desc = "Novo sketch" })
  cmd("ArduinoDecode", function(o)
    local text
    if o.range > 0 then
      text = table.concat(vim.api.nvim_buf_get_lines(0, o.line1 - 1, o.line2, false), "\n")
    end
    M.decode(text)
  end, { range = true, desc = "Decodificar backtrace do ESP32" })

  local group = vim.api.nvim_create_augroup("arduino_nvim", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "arduino",
    callback = function(ev)
      local function map(lhs, rhs, desc, mode)
        vim.keymap.set(mode or "n", "<leader>m" .. lhs, rhs, { buffer = ev.buf, desc = desc })
      end
      map("c", function() M.compile(false) end, "Compilar")
      map("u", function() M.compile(true) end, "Compilar + gravar")
      map("m", function() M.monitor() end, "Monitor serial (toggle)")
      map("p", function() M.pick_port() end, "Porta")
      map("b", function() M.pick_board() end, "Placa")
      map("o", function() M.pick_options() end, "Opções da placa")
      map("l", function() M.lib_search() end, "Bibliotecas")
      map("g", function() M.lsp() end, "Regenerar LSP")
      map("i", function() M.info() end, "Info do sketch")
      map("L", function() M.log() end, "Log do build")
      map("n", function() M.new() end, "Novo sketch")
      map("d", ":ArduinoDecode<cr>", "Decodificar backtrace (seleção)", "x")
      map("d", function() M.decode() end, "Decodificar backtrace (clipboard)")
      local ok, wk = pcall(require, "which-key")
      if ok then
        wk.add({ { "<leader>m", group = "arduino/esp32", buffer = ev.buf, icon = "" } })
      end
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
