return {
  {
    "Shatur/neovim-ayu",
    name = "ayu",
    lazy = true, -- só carrega se rodar :colorscheme ayu (o tema ativo é o min-darker)
    opts = {
      mirage = false,
    },
    config = function(_, opts)
      require("ayu").setup(opts)
    end,
  },
}
