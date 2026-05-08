-- Configuração Ruby para LazyVim
return {
  { import = "lazyvim.plugins.extras.lang.ruby" },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ruby_lsp = {
          mason = false, -- Não instala via Mason, usa a gem global do asdf
          cmd = { "ruby-lsp" },
        },
      },
    },
  },

  -- vim-rails: navegação inteligente em projetos Rails
  -- <leader>gv dentro de um action do controller → abre a view correspondente
  -- <leader>gv dentro de uma view → volta pro controller
  {
    "tpope/vim-rails",
    ft = { "ruby", "eruby" },
    keys = {
      { "<leader>gv", ":R<CR>", ft = { "ruby", "eruby" }, desc = "Go to related view/controller (Rails)" },
    },
  },
}
