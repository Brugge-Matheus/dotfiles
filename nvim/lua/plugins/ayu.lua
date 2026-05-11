return {
  {
    "Shatur/neovim-ayu",
    name = "ayu",
    priority = 1000,
    opts = {
      mirage = false,
    },
    config = function(_, opts)
      require("ayu").setup(opts)
    end,
  },
}
