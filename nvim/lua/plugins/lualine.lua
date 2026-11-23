return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    -- Cores do tema "Terminal Refinado" (ver arch/THEME.md)
    local bg  = "#101012" -- painel
    local fg  = "#8a8a8f" -- texto apagado
    local sel = "#22222a" -- selecao (bloco "a")

    opts.options = opts.options or {}
    opts.options.theme = {
      normal   = { a = { bg = "#d6a84a", fg = "#0b0b0c", gui = "bold" }, b = { bg = bg, fg = fg }, c = { bg = bg, fg = fg } },
      insert   = { a = { bg = "#7ba96a", fg = "#0b0b0c", gui = "bold" }, b = { bg = bg, fg = fg } },
      visual   = { a = { bg = "#eac884", fg = "#0b0b0c", gui = "bold" }, b = { bg = bg, fg = fg } },
      replace  = { a = { bg = "#c87067", fg = "#0b0b0c", gui = "bold" }, b = { bg = bg, fg = fg } },
      command  = { a = { bg = "#8a6e31", fg = "#e7e7e6", gui = "bold" }, b = { bg = bg, fg = fg } },
      inactive = { a = { bg = bg, fg = fg }, b = { bg = bg, fg = fg }, c = { bg = bg, fg = fg } },
    }

    -- Indicador de encoding no canto inferior direito
    -- Aparece sempre; destaca em amarelo quando não é UTF-8
    local encoding_component = {
      function()
        local enc = (vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding):upper()
        -- Normaliza nomes comuns
        if enc == "LATIN1" then enc = "ISO-8859-1" end
        return enc
      end,
      color = function()
        local enc = vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding
        if enc ~= "utf-8" and enc ~= "utf8" then
          return { fg = "#d6a84a", gui = "bold" } -- amarelo para encodings não-UTF-8
        end
        return { fg = "#55555a" } -- cinza sutil para UTF-8
      end,
      padding = { left = 1, right = 1 },
    }

    -- Insere antes do componente de progresso (lualine_y)
    opts.sections = opts.sections or {}
    opts.sections.lualine_y = opts.sections.lualine_y or {}
    table.insert(opts.sections.lualine_y, 1, encoding_component)
  end,
}
