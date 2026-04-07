return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = function()
      local path = vim.fn.stdpath("data") .. "/lazy/markdown-preview.nvim/app"
      vim.fn.system("cd " .. path .. " && npm install && git checkout yarn.lock")
    end,
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
    ft = { "markdown" },
    keys = {
      { "<leader>cp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown Preview" },
    },
  },
}
