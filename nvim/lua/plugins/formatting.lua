return {
  {
    "stevearc/conform.nvim",
    opts = {
      -- format on save desabilitado globalmente via vim.g.autoformat = false (em options.lua)
      formatters_by_ft = {
        php = { "pint" },
      },
      formatters = {
        -- Usa vendor/bin/pint da raiz do projeto (composer.json) se existir, senão o pint global
        pint = {
          command = function(_, ctx)
            local root = vim.fs.root(ctx.filename, { "composer.json", "artisan" })
            local local_pint = root and (root .. "/vendor/bin/pint")
            if local_pint and vim.fn.executable(local_pint) == 1 then
              return local_pint
            end
            return "pint"
          end,
          cwd = function(_, ctx)
            return vim.fs.root(ctx.filename, { "composer.json", "artisan" })
          end,
          args = { "$FILENAME" },
          stdin = false,
        },
      },
    },
  },
}
