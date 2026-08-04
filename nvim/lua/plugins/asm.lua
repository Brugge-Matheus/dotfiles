-- Assembly: asm-lsp (LSP com hover de instruções x86/x86-64/ARM/RISC-V e diagnósticos)
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        asm_lsp = {
          filetypes = { "asm", "s", "vmasm" },
        },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "asm-lsp" })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "asm" })
    end,
  },
}
