-- Use intelephense, não phpactor (o extra lang.php instala via Mason)
vim.g.lazyvim_php_lsp = "intelephense"

return {
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
              files = {
                maxSize = 5000000,
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
}
