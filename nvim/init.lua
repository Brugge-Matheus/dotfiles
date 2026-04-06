-- Garante que o nvim vê o PATH correto do asdf
vim.env.PATH = vim.env.HOME .. "/.asdf/shims:" .. vim.env.PATH

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
