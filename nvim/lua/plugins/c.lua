-- C/C++: clangd (LSP + diagnósticos) + clang-format (formatter)
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          -- "arduino" = sketches .ino (ver lua/arduino/init.lua)
          filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "arduino" },
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy", -- ativa clang-tidy automaticamente se estiver instalado no sistema
            "--completion-style=detailed",
            "--header-insertion=iwyu",
            -- deixa o clangd perguntar ao gcc cruzado (xtensa/avr) os includes do core
            "--query-driver=" .. require("arduino").query_driver(),
          },
        },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "clangd", "clang-format" })
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.c = { "clang-format" }
      opts.formatters_by_ft.cpp = { "clang-format" }
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "c", "cpp", "arduino" })
    end,
  },
}
