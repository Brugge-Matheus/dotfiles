return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
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
          return { fg = "#e5c07b", gui = "bold" } -- amarelo para encodings não-UTF-8
        end
        return { fg = "#6c7086" } -- cinza sutil para UTF-8
      end,
      padding = { left = 1, right = 1 },
    }

    -- Insere antes do componente de progresso (lualine_y)
    opts.sections = opts.sections or {}
    opts.sections.lualine_y = opts.sections.lualine_y or {}
    table.insert(opts.sections.lualine_y, 1, encoding_component)
  end,
}
