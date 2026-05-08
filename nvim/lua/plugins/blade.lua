-- Suporte a arquivos .blade.php (Laravel/Livewire)

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "blade", "php", "html" })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        intelephense = {
          settings = {
            intelephense = {
              environment = { phpVersion = "8.3" },
              stubs = {
                "bcmath", "bz2", "calendar", "Core", "curl", "date",
                "dom", "exif", "fileinfo", "filter", "gd", "gettext",
                "hash", "iconv", "json", "libxml", "mbstring", "meta",
                "mysqli", "openssl", "pcntl", "pcre", "PDO", "pdo_mysql",
                "pdo_pgsql", "pdo_sqlite", "Phar", "posix", "random",
                "readline", "redis", "Reflection", "session", "SimpleXML",
                "soap", "sockets", "sodium", "SPL", "sqlite3", "standard",
                "superglobals", "tokenizer", "xml", "xmlreader", "xmlwriter",
                "zip", "zlib",
              },
              files = { maxSize = 5000000 },
            },
          },
        },
      },
    },
  },

  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "intelephense" })
    end,
  },

  -- gf em cima de <livewire:x /> ou <x-component /> navega para o componente
  {
    "ricardoramirezr/blade-nav.nvim",
    dependencies = { "hrsh7th/nvim-cmp" },
    ft = { "blade", "php" },
    config = function()
      require("blade-nav").setup()
    end,
  },
}
