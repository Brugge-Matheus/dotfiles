-- Diagnósticos (erros/warnings) legíveis quando a mensagem é maior que a janela.
--
-- Problema: o texto virtual no FIM da linha (padrão do LazyVim) é cortado na borda da janela
-- (o Neovim não quebra linha de virtual text), então mensagens longas — comuns em C/C++, ex.:
-- "Format specifies type 'unsigned int' but the argument has type 'unsigned long' [-Wformat]" —
-- ficam ilegíveis.
--
-- Solução (nativa do Neovim 0.11+, sem plugin):
--   • na linha do CURSOR: `virtual_lines` mostra a mensagem COMPLETA em linhas logo abaixo do código,
--     quebrada por palavras na largura da janela (o handler nativo não quebra sozinho, então
--     o `format` abaixo faz isso);
--   • nas OUTRAS linhas: continua o texto curto no fim da linha (cortado se longo — ao passar o
--     cursor na linha, a versão completa aparece).
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

--- colunas úteis da janela atual (descontando número/sinais e a margem do "└──" do virtual_lines)
local function usable_width()
  local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  local w = info and (info.width - info.textoff) or 80
  return math.max(w - 8, 40)
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        -- na linha do cursor quem mostra é o virtual_lines (evita mostrar duas vezes)
        virtual_text = { current_line = false },
        virtual_lines = {
          current_line = true,
          format = function(diagnostic)
            return wrap(diagnostic.message, usable_width())
          end,
        },
      },
    },
  },
}
