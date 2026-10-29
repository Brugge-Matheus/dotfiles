-- Explorer (snacks.nvim) — mostra mais do caminho do ALVO dos symlinks.
--
-- Problema: no projeto ~/svn/ quase todo arquivo em www/<empresa>/ e um symlink
-- p/ bibliotecas/comuns/<arquivo>. O snacks trunca o alvo do link em 20 chars
-- FIXOS (lua/snacks/picker/format.lua: truncpath(real, 20)), o que corta o nome
-- do arquivo -> aparece "bibliotecas/…/…f.php" e nao da p/ identificar.
--
-- Fix: sobrescreve o `format` do source "explorer" — chama o formatador padrao
-- e, no segmento do alvo do link, refaz o truncpath com uma largura maior. O
-- truncpath preserva o FIM do caminho, entao o nome do arquivo (e a pasta pai)
-- ficam visiveis: "…/comuns/rel_smnf.php". Ajuste o numero (LINK_WIDTH) a gosto.
local LINK_WIDTH = 45

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          format = function(item, picker)
            local ret = Snacks.picker.format.file(item, picker)
            if item.type == "link" then
              local uv = vim.uv or vim.loop
              local real = uv.fs_realpath(item.file) or uv.fs_readlink(item.file)
              if real then
                for _, seg in ipairs(ret) do
                  -- segmento do alvo do link (highlight estavel do snacks)
                  if seg[2] == "SnacksPickerLink" or seg[2] == "SnacksPickerLinkBroken" then
                    seg[1] = Snacks.picker.util.truncpath(real, LINK_WIDTH)
                  end
                end
              end
            end
            return ret
          end,
        },
      },
    },
  },
}
