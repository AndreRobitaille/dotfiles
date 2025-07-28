return {
  {
    "stevearc/vim-arduino",
    ft = { "arduino", "ino" },
    config = function()
      vim.g.arduino_use_cli = 1
      vim.g.arduino_serial_baud = 115200

      local function bufmap(lhs, rhs)
        vim.keymap.set("n", lhs, rhs, { buffer = true, silent = true })
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "arduino",
        callback = function()
          bufmap("<leader>aa", "<cmd>ArduinoAttach<CR>")
          bufmap("<leader>av", "<cmd>ArduinoVerify<CR>")
          bufmap("<leader>au", "<cmd>ArduinoUpload<CR>")
          bufmap("<leader>aus", "<cmd>ArduinoUploadAndSerial<CR>")
          bufmap("<leader>as", "<cmd>ArduinoSerial<CR>")
          bufmap("<leader>ab", "<cmd>ArduinoChooseBoard<CR>")
          bufmap("<leader>ap", "<cmd>ArduinoChooseProgrammer<CR>")
          bufmap("<leader>ao", "<cmd>ArduinoChoosePort<CR>")
          bufmap("<leader>ai", "<cmd>ArduinoInfo<CR>")
        end,
      })
    end,
  },
  {
    -- "mason-org/mason-lspconfig.nvim",
    "williamboman/mason-lspconfig.nvim",
    opts = {
      ensure_installed = { "arduino_language_server" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      setup = {
        arduino_language_server = false, -- <- tell lazyvim *not* to auto-setup
      },
    },
    config = function()
      ----------------------------------------------------------------
      -- create a one-shot autocmd
      ----------------------------------------------------------------
      local group = vim.api.nvim_create_augroup("ArduinoLspAutoload", {})
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "arduino", "ino" },
        callback = function()
          ----------------------------------------------------------------
          -- (a) autodetect board  ---------------------------------------
          ----------------------------------------------------------------
          local json_decode = (vim.json and vim.json.decode) or vim.fn.json_decode
          local fqbn = "arduino:avr:uno" -- default fallback
          local ok, raw = pcall(vim.fn.system, {
            "arduino-cli",
            "board",
            "list",
            "--format",
            "json",
          })
          if ok and raw ~= "" then
            local data = json_decode(raw)
            if data and data.boards then
              for _, b in ipairs(data.boards) do
                if b.FQBN and b.FQBN ~= "" then
                  fqbn = b.FQBN
                  break
                end
              end
            end
          end
          -- env override
          if vim.env.ARDUINO_FQBN and vim.env.ARDUINO_FQBN ~= "" then
            fqbn = vim.env.ARDUINO_FQBN
          end
          print("Arduino LSP → board: " .. fqbn)

          ----------------------------------------------------------------
          -- (b) customise caps for NVim-0.10  ---------------------------
          ----------------------------------------------------------------
          local caps = vim.lsp.protocol.make_client_capabilities()
          caps.textDocument.semanticTokens = nil
          caps.workspace.semanticTokens = nil

          ----------------------------------------------------------------
          -- (c) start the language server ------------------------------
          ----------------------------------------------------------------
          require("lspconfig").arduino_language_server.setup({
            cmd = {
              "arduino-language-server",
              "-cli",
              "arduino-cli",
              "-cli-config",
              vim.fn.expand("~/.config/arduino-cli.yaml"),
              "-clangd",
              "clangd",
              "-fqbn",
              fqbn,
            },
            capabilities = caps,
          })

          ----------------------------------------------------------------
          -- (d) drop the autocmd so we don't rerun on every Arduino file
          ----------------------------------------------------------------
          vim.api.nvim_del_augroup_by_id(group)
        end,
      })
    end,
  },
}
