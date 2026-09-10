-- Preview file Markdown trong Neovim.
--
-- Hai lop bo tro nhau:
--   1. render-markdown.nvim  -> render ngay trong buffer, khong roi nvim
--   2. markdown-preview.nvim -> mo preview live tren trinh duyet (HTML that)
return {
  -- 1. In-buffer preview: an dau ###, ve heading/bang/checkbox/code block dep hon.
  -- Tu bat khi mo file .md, con dang chinh sua thi dong duoi con tro tro ve
  -- markdown tho de sua cho chinh xac.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "markdown_inline", "codecompanion" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
    opts = {
      -- Render o normal/command/terminal mode; sang insert/visual thi tra ve
      -- markdown tho de sua cho chinh xac. <leader>mp tat/bat han.
      render_modes = { "n", "c", "t" },
      heading = {
        sign = false,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
      code = {
        sign = false,
        width = "block",
        right_pad = 2,
      },
      checkbox = {
        unchecked = { icon = "󰄱 " },
        checked = { icon = "󰱒 " },
      },
    },
    keys = {
      {
        "<leader>mp",
        function()
          require("render-markdown").toggle()
        end,
        ft = "markdown",
        desc = "Markdown: bat/tat preview trong buffer",
      },
    },
  },

  -- 2. Browser preview: live reload, cuon dong bo voi con tro trong nvim.
  -- build tai binary server dung san ve app/bin/.
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    -- lazy.nvim chay build truoc khi plugin vao runtimepath, nen ham autoload
    -- mkdp#util#install chua ton tai. Them dir vao rtp roi moi goi.
    build = function(plugin)
      vim.opt.runtimepath:append(plugin.dir)
      vim.cmd("runtime! plugin/mkdp.vim")
      vim.fn["mkdp#util#install"]()
    end,
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_theme = "dark"
    end,
    keys = {
      {
        "<leader>mb",
        "<cmd>MarkdownPreviewToggle<cr>",
        ft = "markdown",
        desc = "Markdown: bat/tat preview tren browser",
      },
    },
  },

  -- Parser markdown cho treesitter (render-markdown.nvim phu thuoc vao day).
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "markdown", "markdown_inline" })
    end,
  },

  -- Nhan <leader>m trong which-key
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>m", group = "markdown", icon = "󰍔 " },
      },
    },
  },
}
