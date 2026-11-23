-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "jj", "<Esc>", { desc = "Sair do insert mode" })
vim.keymap.set("n", "<leader>/", "<cmd>noh<cr>", { desc = "Limpar highlight de busca" })

-- Navegação entre buffers (segue a ordem visual do bufferline, não o número do buffer)
pcall(vim.keymap.del, "n", "<leader>l")
vim.keymap.set("n", "<leader>h", "<cmd>BufferLineCyclePrev<cr>", { desc = "Buffer anterior" })
vim.keymap.set("n", "<leader>l", "<cmd>BufferLineCycleNext<cr>", { desc = "Próximo buffer" })

-- Reordenar buffers na tabline
pcall(vim.keymap.del, "n", "[B")
pcall(vim.keymap.del, "n", "]B")
vim.keymap.set("n", "[l", "<cmd>BufferLineMovePrev<cr>", { desc = "Mover buffer para esquerda" })
vim.keymap.set("n", "]l", "<cmd>BufferLineMoveNext<cr>", { desc = "Mover buffer para direita" })

-- Duplicar linha (como Shift+Alt+Down/Up no VSCode)
local function duplicate_line_down()
  local line = vim.api.nvim_get_current_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, { line })
end

local function duplicate_line_up()
  local line = vim.api.nvim_get_current_line()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { line })
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

vim.keymap.set({ "n", "i" }, "<M-J>", duplicate_line_down, { desc = "Duplicate line down" })
vim.keymap.set({ "n", "i" }, "<M-K>", duplicate_line_up, { desc = "Duplicate line up" })

-- Visual *: confirma busca pela seleção (multi-linha incluído) e permite n/N
vim.keymap.set("x", "*", function()
  vim.cmd('noau normal! "vy')
  local text = vim.fn.getreg("v")
  if text == "" then return end
  vim.fn.setreg("/", "\\V" .. vim.fn.escape(text, "\\"):gsub("\n", "\\n"))
  vim.opt.hlsearch = true
  -- Volta para normal mode posicionado no início da seleção
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>``", true, false, true), "n", false)
end, { desc = "Buscar seleção visual + n/N para navegar" })

-- Importar namespace da classe sob o cursor (usa code action do LSP, ex: intelephense)
vim.keymap.set("n", "<leader>ci", function()
  vim.lsp.buf.code_action({
    context = { only = { "quickfix", "source" }, diagnostics = {} },
    filter = function(action)
      local title = (action.title or ""):lower()
      return title:match("import") or title:match("use ")
    end,
    apply = true,
  })
end, { desc = "Importar namespace da classe sob o cursor" })

-- Trocar a codificacao do arquivo aberto, SO neste buffer (<leader>ce).
-- Ao fechar o buffer e reabrir o arquivo volta a codificacao padrao (config/autocmds.lua: ~/svn = latin1, .md = UTF-8).
--   Recarregar lendo como X : corrige o texto quebrado ("Ã§" em vez de "ç"); descarta edicoes nao salvas (pede confirmacao)
--   Converter ao salvar p/ X: o texto na tela nao muda; o PROXIMO :w grava o arquivo em X
vim.keymap.set("n", "<leader>ce", function()
  local encs = {
    { "utf-8", "UTF-8" },
    { "latin1", "ISO-8859-1 (Latin-1)" },
    { "cp1252", "Windows-1252" },
    { "utf-16le", "UTF-16 LE" },
    { "utf-16", "UTF-16" },
  }
  local cur = (vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding)
  vim.ui.select(encs, {
    prompt = "Codificacao (atual: " .. cur .. ")",
    format_item = function(e) return e[2] .. (e[1] == cur and "  ← atual" or "") end,
  }, function(enc)
    if not enc then return end
    local buf = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_name(buf) == "" then
      vim.bo[buf].fileencoding = enc[1]
      return vim.notify("Este buffer sera gravado como " .. enc[2])
    end
    vim.ui.select({ "Recarregar lendo como " .. enc[2], "Converter ao salvar para " .. enc[2] }, {
      prompt = "O que fazer?",
    }, function(_, idx)
      if not idx then return end
      if idx == 1 then
        if vim.bo[buf].modified then
          if vim.fn.confirm("Ha alteracoes nao salvas; recarregar descarta tudo. Continuar?", "&Sim\n&Nao", 2) ~= 1 then
            return
          end
        end
        vim.cmd("edit! ++enc=" .. enc[1])
        vim.notify("Relido como " .. enc[2] .. " (so neste buffer)")
      else
        vim.bo[buf].fileencoding = enc[1]
        vim.notify("O proximo :w grava como " .. enc[2] .. " (so neste buffer)")
      end
    end)
  end)
end, { desc = "Trocar codificacao do arquivo (so neste buffer)" })
