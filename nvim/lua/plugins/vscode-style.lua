return {
  -- Git blame inline (como na screenshot do VSCode)
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 300,
        virt_text_pos = "eol", -- mostra no final da linha
      },
      current_line_blame_formatter = "  <author>, <author_time:%d/%m/%Y> • <summary>",
    },
  },

  -- Sticky scroll: contexto da função visível no topo (como stickyScroll do VSCode)
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "BufReadPost",
    opts = {
      max_lines = 3,
      min_window_height = 20,
      mode = "cursor",
    },
  },

  -- Ícones no file explorer (como o icon theme "symbols" do VSCode)
  {
    "nvim-tree/nvim-web-devicons",
    opts = {},
  },
}
