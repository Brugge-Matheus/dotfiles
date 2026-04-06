return {
  "dawsers/file-history.nvim",
  dependencies = { "folke/snacks.nvim" },
  config = function()
    require("file_history").setup({
      backup_dir = "~/.file-history-git",
    })

    local fh = require("file_history")
    vim.keymap.set("n", "<leader>fhh", function() fh.history() end, { desc = "File History (arquivo atual)" })
    vim.keymap.set("n", "<leader>fhf", function() fh.files() end,   { desc = "File History (todos arquivos)" })
    vim.keymap.set("n", "<leader>fhb", function() fh.backup() end,  { desc = "File History: backup manual" })
    vim.keymap.set("n", "<leader>fhq", function() fh.query() end,   { desc = "File History: buscar por data" })
  end,
}
