return {
  {
    "stevearc/conform.nvim",
    opts = {
      -- format on save desabilitado globalmente via vim.g.autoformat = false (em options.lua)
      formatters_by_ft = {
        php = { "pint" },
      },
      formatters = {
        -- Usa vendor/bin/pint se existir no projeto, senão usa o pint global
        pint = {
          command = function()
            local local_pint = vim.fn.getcwd() .. "/vendor/bin/pint"
            if vim.fn.executable(local_pint) == 1 then
              return local_pint
            end
            return "pint"
          end,
          args = { "$FILENAME" },
          stdin = false,
        },
      },
    },
  },
}
