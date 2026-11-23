-- Diagnósticos (erros/warnings) legíveis quando a mensagem é maior que a janela.
--
-- Problema: o texto virtual no FIM da linha (padrão do LazyVim) é cortado na borda da janela (o Neovim
-- não quebra virtual text), e o `virtual_lines` nativo recua a mensagem até a COLUNA do diagnóstico —
-- se ele está perto da borda direita (ex.: `#include <stdio.h>` com o cursor no fim da linha), a
-- mensagem também sai da tela.
--
-- Solução (sem plugin): handler próprio `cursor_lines`, só para a linha do CURSOR:
--   • a mensagem COMPLETA vai em linhas logo abaixo do código, quebrada por palavras na largura da janela;
--   • o recuo é a coluna do diagnóstico QUANDO CABE; senão é puxado p/ a esquerda o mínimo necessário
--     (a mensagem nunca sai da tela e continua "apontando" p/ o código quando possível);
--   • nas OUTRAS linhas: continua o texto curto no fim da linha (ao passar o cursor, a versão completa aparece).
-- Mensagem completa também em: <leader>cd (float, já quebra) e `]d` / `[d` p/ navegar.

--- quebra `text` em linhas de até `width` colunas (por palavras; palavra gigante é fatiada)
local function wrap(text, width)
  local out = {}
  for _, para in ipairs(vim.split(text, "\n", { plain = true })) do
    local line = ""
    for word in para:gmatch("%S+") do
      while vim.fn.strdisplaywidth(word) > width do -- ex.: caminho enorme sem espaços
        if line ~= "" then
          out[#out + 1] = line
          line = ""
        end
        out[#out + 1] = vim.fn.strcharpart(word, 0, width)
        word = vim.fn.strcharpart(word, width)
      end
      if line ~= "" and vim.fn.strdisplaywidth(line .. " " .. word) > width then
        out[#out + 1] = line
        line = word
      else
        line = (line == "") and word or (line .. " " .. word)
      end
    end
    out[#out + 1] = line
  end
  return table.concat(out, "\n")
end

local ns = vim.api.nvim_create_namespace("cursor_lines")
local aug = vim.api.nvim_create_augroup("cursor_lines", { clear = true })
local hl = { "DiagnosticVirtualLinesError", "DiagnosticVirtualLinesWarn", "DiagnosticVirtualLinesInfo", "DiagnosticVirtualLinesHint" }

local function render(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  if bufnr ~= vim.api.nvim_get_current_buf() then return end
  local win = vim.api.nvim_get_current_win()
  local lnum = vim.api.nvim_win_get_cursor(win)[1] - 1
  local info = vim.fn.getwininfo(win)[1]
  local total = info and (info.width - info.textoff) or 80
  local tab = {}
  for _, d in ipairs(vim.diagnostic.get(bufnr, { lnum = lnum })) do tab[#tab + 1] = d end
  if #tab == 0 then return end
  table.sort(tab, function(a, b) return a.severity < b.severity end)
  local virt, last = {}, lnum
  for _, d in ipairs(tab) do
    local msg = d.code and (d.code .. ": " .. d.message) or d.message
    local lines = vim.split(wrap(msg, math.max(total - 8, 30)), "\n", { plain = true })
    local widest = 0
    for _, l in ipairs(lines) do widest = math.max(widest, vim.fn.strdisplaywidth(l)) end
    local line_text = vim.api.nvim_buf_get_lines(bufnr, d.lnum, d.lnum + 1, false)[1] or ""
    local col = vim.fn.strdisplaywidth(line_text:sub(1, d.col))
    local indent = math.max(0, math.min(col, total - widest - 6)) -- puxa p/ esquerda só o necessário
    local h = hl[d.severity] or hl[1]
    for i, l in ipairs(lines) do
      virt[#virt + 1] = { { string.rep(" ", indent), "" }, { (i == 1 and "└──── " or "      ") .. l, h } }
    end
    last = math.max(last, d.end_lnum or d.lnum)
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns, last, 0, { virt_lines = virt })
end

vim.diagnostic.handlers.cursor_lines = {
  show = function(_, bufnr)
    vim.api.nvim_clear_autocmds({ group = aug, buffer = bufnr })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinResized", "DiagnosticChanged" }, {
      group = aug, buffer = bufnr, callback = function() render(bufnr) end,
    })
    render(bufnr)
  end,
  hide = function(_, bufnr)
    vim.api.nvim_clear_autocmds({ group = aug, buffer = bufnr })
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1)
  end,
}

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        -- na linha do cursor quem mostra é o handler `cursor_lines` (evita mostrar duas vezes)
        virtual_text = { current_line = false },
        virtual_lines = false,
        cursor_lines = true,
      },
    },
  },
}
