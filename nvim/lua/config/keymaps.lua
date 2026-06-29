-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "jj", "<Esc>", { desc = "Sair do insert mode" })
vim.keymap.set("n", "<leader>/", "<cmd>noh<cr>", { desc = "Limpar highlight de busca" })

-- Navegação entre buffers
pcall(vim.keymap.del, "n", "<leader>l")
vim.keymap.set("n", "<leader>h", "<cmd>bprevious<cr>", { desc = "Buffer anterior" })
vim.keymap.set("n", "<leader>l", "<cmd>bnext<cr>", { desc = "Próximo buffer" })

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
