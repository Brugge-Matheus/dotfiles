-- Substitui o workaround de semantic tokens do LazyVim (usa Snacks.util.lsp.on
-- que acessa client.config.capabilities de forma insegura no Neovim 0.11+)
-- por uma abordagem via LspAttach com acesso nil-safe usando vim.tbl_get.
return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.setup = opts.setup or {}
      opts.setup.gopls = function()
        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(ev)
            local client = vim.lsp.get_client_by_id(ev.data.client_id)
            if not client or client.name ~= "gopls" then return end
            if client.server_capabilities.semanticTokensProvider then return end
            local semantic = vim.tbl_get(client, "config", "capabilities", "textDocument", "semanticTokens")
            if not semantic then return end
            client.server_capabilities.semanticTokensProvider = {
              full = true,
              legend = {
                tokenTypes = semantic.tokenTypes,
                tokenModifiers = semantic.tokenModifiers,
              },
              range = true,
            }
          end,
        })
      end
    end,
  },
}
