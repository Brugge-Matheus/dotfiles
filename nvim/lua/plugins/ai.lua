return {
  -- Supermaven: AI inline gratuita, baixa latência, bom contexto para PHP/Laravel/Ruby
  -- Primeiro uso: :SupermavenUseFree para ativar sem conta, ou :SupermavenUseProToken para Pro
  {
    "supermaven-inc/supermaven-nvim",
    event = "InsertEnter",
    opts = {
      keymaps = {
        accept_suggestion = "<Tab>",
        clear_suggestion = "<C-]>",
        accept_word = "<C-j>",
      },
      ignore_filetypes = { "help", "gitcommit" },
      color = {
        suggestion_color = "#6c7086", -- cinza discreto (compatível com tokyonight)
      },
      log_level = "off",
    },
  },
}
