return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        intelephense = {
          settings = {
            intelephense = {
              files = {
                -- Reconhece .inc e .phtml como PHP
                associations = { "*.php", "*.inc", "*.phtml", "*.blade.php" },
              },
              diagnostics = {
                -- Desliga falsos positivos comuns em projetos legados sem namespaces/docblocks
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
    -- Trata .inc como PHP no Neovim (treesitter, formatters, etc.)
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
