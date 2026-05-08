return {
  {
    "zbirenbaum/copilot.lua",
    enabled = false,
  },
  {
    "fang2hou/blink-copilot",
    enabled = false,
  },
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.completion = opts.completion or {}
      opts.completion.ghost_text = { enabled = false }

      opts.sources = opts.sources or {}
      opts.sources.default = { "lsp", "path" }

      opts.sources.providers = opts.sources.providers or {}
      opts.sources.providers.lsp = vim.tbl_deep_extend("force", opts.sources.providers.lsp or {}, {
        score_offset = 100,
      })

      -- Remove copilot das sources default
      opts.sources.default = vim.tbl_filter(function(s)
        return s ~= "copilot"
      end, opts.sources.default or {})
      -- Remove o provider copilot
      if opts.sources.providers then
        opts.sources.providers.copilot = nil
      end
      return opts
    end,
  },
  {
    "coder/claudecode.nvim",
    keys = {
      { "<leader>aa", false },
      { "<leader>aA", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
    },
  },
}
