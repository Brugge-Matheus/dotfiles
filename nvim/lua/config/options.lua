-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.clipboard = "unnamedplus" -- yank/delete vai direto para o clipboard do sistema
vim.opt.backupcopy = "yes"        -- evita que watchers (bun --watch, webpack) percam o arquivo ao salvar
vim.opt.wrap = true               -- quebra linhas longas (sem scroll lateral)
vim.opt.linebreak = true          -- quebra na palavra, não no meio dela

-- VSCode style
vim.opt.cursorlineopt = "number"      -- highlight só no número da linha (como renderLineHighlight: gutter)
vim.opt.scrolloff = 8                 -- mantém contexto ao rolar
vim.opt.guifont = "JetBrainsMono Nerd Font:h18" -- fonte (para Neovide ou GUI)
