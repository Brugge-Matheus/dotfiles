return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    -- Cores exatas do statusBar do Min Darker Theme
    local bg  = "#070707" -- statusBar.background
    local fg  = "#7E7E7E" -- statusBar.foreground
    local sel = "#303030" -- list.activeSelectionBackground (usado no bloco "a")

    opts.options = opts.options or {}
    opts.options.theme = {
      normal   = { a = { bg = sel, fg = "#FAFAFA", gui = "bold" }, b = { bg = bg, fg = fg }, c = { bg = bg, fg = fg } },
      insert   = { a = { bg = "#c74e39", fg = "#FAFAFA", gui = "bold" }, b = { bg = bg, fg = fg } },
      visual   = { a = { bg = "#b392f0", fg = "#0C0C0C", gui = "bold" }, b = { bg = bg, fg = fg } },
      replace  = { a = { bg = "#FF9800", fg = "#0C0C0C", gui = "bold" }, b = { bg = bg, fg = fg } },
      command  = { a = { bg = "#81b88b", fg = "#0C0C0C", gui = "bold" }, b = { bg = bg, fg = fg } },
      inactive = { a = { bg = bg, fg = fg }, b = { bg = bg, fg = fg }, c = { bg = bg, fg = fg } },
    }

    -- Indicador de encoding no canto inferior direito
    -- Aparece sempre; destaca em amarelo quando não é UTF-8
    local encoding_component = {
      function()
        local enc = (vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding):upper()
        if enc == "LATIN1" then enc = "ISO-8859-1" end
        return enc
      end,
      color = function()
        local enc = vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding
        if enc ~= "utf-8" and enc ~= "utf8" then
          return { fg = "#e5c07b", gui = "bold" }
        end
        return { fg = "#6c7086" }
      end,
      padding = { left = 1, right = 1 },
    }

    opts.sections = opts.sections or {}
    opts.sections.lualine_y = opts.sections.lualine_y or {}
    table.insert(opts.sections.lualine_y, 1, encoding_component)
  end,
}
