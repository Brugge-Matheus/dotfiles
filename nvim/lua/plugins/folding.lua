return {
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufReadPost",
    opts = {
      provider_selector = function(_, filetype, _)
        local ft_map = {
          php = { "lsp", "indent" },
          lua = { "treesitter", "indent" },
          go  = { "lsp", "indent" },
          ruby = { "treesitter", "indent" },
        }
        return ft_map[filetype] or { "indent" }
      end,
    },
    init = function()
      vim.opt.foldcolumn   = "0"
      vim.opt.foldlevel    = 99
      vim.opt.foldlevelstart = 99
      vim.opt.foldenable   = true
    end,
    keys = {
      { "zR", function() require("ufo").openAllFolds() end,          desc = "Abrir todos os folds" },
      { "zM", function() require("ufo").closeAllFolds() end,         desc = "Fechar todos os folds" },
      { "zr", function() require("ufo").openFoldsExceptKinds() end,  desc = "Abrir folds (exceto imports)" },
      { "K", function()
        local winid = require("ufo").peekFoldedLinesUnderCursor()
        if not winid then vim.lsp.buf.hover() end
      end, desc = "Peek fold / Hover" },
    },
  },
}
