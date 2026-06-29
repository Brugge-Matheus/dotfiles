-- Use intelephense, não phpactor
vim.g.lazyvim_php_lsp = "intelephense"

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        intelephense = {
          settings = {
            intelephense = {
              files = {
                associations = { "*.php", "*.inc", "*.phtml", "*.blade.php" },
              },
              diagnostics = {
                undefinedTypes = false,
                undefinedFunctions = false,
                undefinedConstants = false,
                undefinedClassConstants = false,
                undefinedMethods = false,
                undefinedProperties = false,
                missingDocblocks = false,
              },
            },
          },
        },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        php = {}, -- desliga phpcs
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.filetype.add({
        extension = {
          inc = "php",
          phtml = "php",
        },
      })
    end,
  },
}
