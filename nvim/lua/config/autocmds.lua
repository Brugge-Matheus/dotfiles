-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Encoding por projeto: força fileencodings antes da leitura do arquivo
-- ~/svn usa Latin-1 (ISO-8859-1); demais projetos usam UTF-8
local PROJECT_ENCODINGS = {
  { path = vim.fn.expand("~/svn/"), encoding = "latin1" },
}
local DEFAULT_ENCODINGS = "ucs-bom,utf-8,default,latin1"

vim.api.nvim_create_autocmd("BufReadPre", {
  callback = function(ev)
    local path = vim.fn.fnamemodify(ev.match, ":p")
    for _, entry in ipairs(PROJECT_ENCODINGS) do
      if path:sub(1, #entry.path) == entry.path then
        vim.opt.fileencodings = entry.encoding
        return
      end
    end
    vim.opt.fileencodings = DEFAULT_ENCODINGS
  end,
})

-- Highlight em tempo real de todas as ocorrências da seleção visual (como VSCode)
-- Funciona para seleções de linha única com 2+ caracteres
vim.api.nvim_create_augroup("VisualHighlight", { clear = true })
vim.api.nvim_create_autocmd("CursorMoved", {
  group = "VisualHighlight",
  callback = function()
    if vim.fn.mode() ~= "v" then return end

    local vs = vim.fn.getpos("v")
    local vc = vim.fn.getpos(".")
    local sl, sc = vs[2], vs[3]
    local el, ec = vc[2], vc[3]

    if sl ~= el then return end             -- ignora seleção multi-linha
    if sc > ec then sc, ec = ec, sc end

    local line = vim.api.nvim_buf_get_lines(0, sl - 1, sl, false)[1] or ""
    local text = line:sub(sc, ec)
    if #text < 2 then return end            -- mínimo 2 chars para não poluir

    vim.fn.setreg("/", "\\V" .. vim.fn.escape(text, "\\"))
    vim.opt.hlsearch = true
  end,
})

-- Apaga swap de processos mortos automaticamente (evita W325)
vim.api.nvim_create_autocmd("SwapExists", {
  callback = function()
    local info = vim.fn.swapinfo(vim.v.swapname)
    local pid = info and info.pid
    if pid and vim.fn.system("kill -0 " .. pid .. " 2>/dev/null; echo $?"):gsub("\n", "") ~= "0" then
      vim.v.swapchoice = "d"
    end
  end,
})

-- Pisca o texto copiado por 1 segundo
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight on yank",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 1000 })
  end,
})

-- PHP: <leader>cn importa o namespace da classe sob o cursor
-- <leader>gv abre a view retornada pelo método atual do controller
vim.api.nvim_create_autocmd("FileType", {
  pattern = "php",
  callback = function()
    -- Import namespace via composer autoload_classmap.php
    vim.keymap.set("n", "<leader>cn", function()
      local word = vim.fn.expand("<cword>")
      if word == "" then return end

      -- Encontra a raiz do projeto Laravel (onde está o artisan)
      local artisan = vim.fn.findfile("artisan", ".;")
      if artisan == "" then
        vim.notify("Raiz do Laravel não encontrada (artisan ausente)", vim.log.levels.WARN)
        return
      end
      local root = vim.fn.fnamemodify(artisan, ":h")
      local classmap = root .. "/vendor/composer/autoload_classmap.php"

      if vim.fn.filereadable(classmap) == 0 then
        vim.notify("autoload_classmap.php não encontrado — rode composer install", vim.log.levels.WARN)
        return
      end

      -- Busca entradas que terminam com \ClassName ou \ClassName (versão escaped do PHP \\)
      local results = vim.fn.systemlist(
        "rg " .. vim.fn.shellescape("\\\\" .. word .. "'") .. " " .. vim.fn.shellescape(classmap)
      )

      if #results == 0 then
        vim.notify("'" .. word .. "' não encontrado no autoload", vim.log.levels.WARN)
        return
      end

      -- Extrai o FQN de cada linha: 'Namespace\\ClassName' => ...
      local candidates = {}
      local seen = {}
      for _, line in ipairs(results) do
        local fqn = line:match("'([^']+)'")
        if fqn then
          fqn = fqn:gsub("\\\\", "\\")
          if not seen[fqn] then
            seen[fqn] = true
            table.insert(candidates, fqn)
          end
        end
      end

      if #candidates == 0 then
        vim.notify("Nenhum namespace encontrado para '" .. word .. "'", vim.log.levels.WARN)
        return
      end

      local function insert_use(fqn)
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        for _, line in ipairs(lines) do
          if line == "use " .. fqn .. ";" then
            vim.notify("Já importado: " .. fqn, vim.log.levels.INFO)
            return
          end
        end
        local insert_at = 0
        for i, line in ipairs(lines) do
          if line:match("^use ") then
            insert_at = i
          elseif line:match("^namespace ") and insert_at == 0 then
            insert_at = i
          end
        end
        vim.api.nvim_buf_set_lines(0, insert_at, insert_at, false, { "use " .. fqn .. ";" })
        vim.notify("Importado: " .. fqn, vim.log.levels.INFO)
      end

      if #candidates == 1 then
        insert_use(candidates[1])
      else
        vim.ui.select(candidates, { prompt = "Importar classe:" }, function(choice)
          if choice then insert_use(choice) end
        end)
      end
    end, { buffer = true, desc = "PHP: import class namespace" })

    -- Goto view
    vim.keymap.set("n", "<leader>gv", function()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      local method_start = cursor_line
      for i = cursor_line, 1, -1 do
        if lines[i]:match("function%s+%w+") then
          method_start = i
          break
        end
      end
      local view_path
      for i = method_start, math.min(#lines, method_start + 60) do
        view_path = lines[i]:match("view%(%s*['\"]([^'\"]+)['\"]")
        if view_path then break end
      end
      if not view_path then
        vim.notify("Nenhum view() encontrado no método atual", vim.log.levels.WARN)
        return
      end
      local artisan = vim.fn.findfile("artisan", ".;")
      if artisan == "" then
        vim.notify("Raiz do Laravel não encontrada", vim.log.levels.WARN)
        return
      end
      local full_path = vim.fn.fnamemodify(artisan, ":h") ..
        "/resources/views/" .. view_path:gsub("%.", "/") .. ".blade.php"
      if vim.fn.filereadable(full_path) == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(full_path))
      else
        vim.notify("View não encontrada: " .. full_path, vim.log.levels.WARN)
      end
    end, { buffer = true, desc = "PHP: goto Laravel view" })

    -- gd em blade → gf (LSP não resolve tags Livewire/Blade)
    vim.keymap.set("n", "gd", "gf", { buffer = true, remap = true, desc = "Go to Blade/Livewire component" })
  end,
})

-- Restaura o cursor na última posição ao reabrir um arquivo
vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "Restore cursor position",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})
