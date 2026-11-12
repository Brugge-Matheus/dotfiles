return {
  "dawsers/file-history.nvim",
  dependencies = { "folke/snacks.nvim" },
  -- O backup automático é um BufWritePost criado no setup(): basta carregar antes do
  -- primeiro arquivo ser aberto, não precisa estar no startup
  event = { "BufReadPre", "BufNewFile" },
  keys = {
    { "<leader>fhh", function() require("file_history").history() end, desc = "File History (arquivo atual)" },
    { "<leader>fhf", function() require("file_history").files() end,   desc = "File History (todos arquivos)" },
    { "<leader>fhb", function() require("file_history").backup() end,  desc = "File History: backup manual" },
    { "<leader>fhq", function() require("file_history").query() end,   desc = "File History: buscar por data" },
  },
  opts = {
    backup_dir = "~/.file-history-git",
  },
  config = function(_, opts)
    require("file_history").setup(opts)
  end,
}
