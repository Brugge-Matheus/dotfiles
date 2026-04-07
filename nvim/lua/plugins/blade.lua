-- Suporte a arquivos .blade.php (Laravel/Livewire)

return {
  -- Parser blade já incluso no nvim-treesitter, só precisa instalar
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "blade", "php", "html" })
    end,
  },

  -- LSP: intelephense para PHP/Blade
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        intelephense = {},
      },
    },
  },

  -- Instala intelephense via Mason
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "intelephense" })
    end,
  },
}
