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
}
