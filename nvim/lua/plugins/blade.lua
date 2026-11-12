-- Suporte a arquivos .blade.php (Laravel/Livewire)
-- (LSP intelephense fica em php.lua; o filetype blade é registrado no init.lua)

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "blade", "php", "html" })
    end,
  },

  -- gf em cima de <livewire:x /> ou <x-component /> navega para o componente
  {
    "ricardoramirezr/blade-nav.nvim",
    ft = { "blade", "php" },
    config = function()
      require("blade-nav").setup()
    end,
  },

  -- Completion de componentes/rotas/views do blade-nav via blink.cmp
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        per_filetype = {
          blade = { "blade-nav", inherit_defaults = true },
          php = { "blade-nav", inherit_defaults = true },
        },
        providers = {
          ["blade-nav"] = {
            name = "blade-nav",
            module = "blade-nav.integrations.blink",
          },
        },
      },
    },
  },
}
