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
      -- Remove copilot das sources default
      opts.sources = opts.sources or {}
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
}
