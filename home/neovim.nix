# --- neovim ---
# The existing user config loads lua/p10k.lua. Manage that theme bridge here so
# its palette follows system/theme.nix while the rest of the plugin config stays
# user-owned and unchanged.
{ pkgs, theme, ... }:
let
  themeModule = pkgs.writeText "koru-nvim-p10k.lua" ''
    local M = {}
    M.colors = {
      cream = "${theme.fg}",
      apricot = "${theme.accent-yellow}",
      terracotta = "${theme.ansi.red}",
      brown = "${theme.accent}",
      stone = "${theme.muted-alt}",
      dark = "${theme.bg}",
    }

    local function rgb(hex)
      hex = hex:gsub("#", "")
      return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
    end
    function M.mix(c1, c2, t)
      local r1, g1, b1 = rgb(c1)
      local r2, g2, b2 = rgb(c2)
      local mix = function(a, b) return a + (b - a) * t end
      return string.format("#%02x%02x%02x", math.floor(mix(r1, r2) + 0.5), math.floor(mix(g1, g2) + 0.5), math.floor(mix(b1, b2) + 0.5))
    end

    local function hl(group, opts) vim.api.nvim_set_hl(0, group, opts) end
    local function syntax(groups, color)
      for _, group in ipairs(groups) do hl(group, { fg = color }) end
    end

    function M.setup()
      local c = M.colors
      for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "MsgArea" }) do
        hl(group, { fg = c.cream, bg = "none" })
      end
      hl("EndOfBuffer", { fg = c.stone, bg = "none" })
      hl("NonText", { fg = c.stone, bg = "none" })
      hl("Whitespace", { fg = c.stone, bg = "none" })
      hl("FloatBorder", { fg = c.brown, bg = "none" })
      hl("FloatTitle", { fg = c.dark, bg = c.apricot, bold = true })
      hl("WinSeparator", { fg = c.brown, bg = "none" })
      hl("StatusLine", { fg = c.cream, bg = "none" })
      hl("StatusLineNC", { fg = c.stone, bg = "none" })
      hl("TabLineSel", { fg = c.dark, bg = c.apricot, bold = true })
      hl("CursorLineNr", { fg = c.apricot, bold = true })
      hl("LineNr", { fg = c.stone })
      hl("LineNrAbove", { fg = c.brown })
      hl("LineNrBelow", { fg = c.stone })
      hl("Cursor", { fg = c.dark, bg = c.cream })
      hl("Visual", { fg = c.dark, bg = c.brown })
      hl("MatchParen", { fg = c.apricot, bold = true, underline = true })
      hl("Search", { fg = c.dark, bg = c.apricot })
      hl("Pmenu", { fg = c.cream, bg = c.dark })
      hl("PmenuSel", { fg = c.dark, bg = c.apricot })
      hl("ModeMsg", { fg = c.apricot, bold = true })
      hl("MoreMsg", { fg = c.brown })
      hl("ErrorMsg", { fg = c.terracotta, bold = true })
      hl("WarningMsg", { fg = c.apricot, bold = true })
      hl("Directory", { fg = c.brown })
      hl("Title", { fg = c.apricot, bold = true })
      hl("Todo", { fg = c.dark, bg = c.apricot, bold = true })

      syntax({ "Comment", "SpecialComment" }, c.stone)
      syntax({ "Constant", "Number", "Boolean", "Float" }, c.apricot)
      syntax({ "Identifier", "String", "Character" }, c.cream)
      syntax({ "Function", "Type", "StorageClass", "Structure", "Typedef" }, c.brown)
      syntax({ "Statement", "Conditional", "Repeat", "Label", "Operator", "Keyword", "Exception" }, c.brown)
      syntax({ "PreProc", "Include", "Define", "Macro", "PreCondit", "Special", "SpecialChar" }, c.apricot)
      hl("Delimiter", { fg = c.stone })
      hl("Underlined", { fg = c.apricot, underline = true })
      hl("Error", { fg = c.terracotta, bold = true })

      local treesitter = {
        ["@comment"] = { fg = c.stone, italic = true },
        ["@keyword"] = { fg = c.brown }, ["@operator"] = { fg = c.brown },
        ["@string"] = { fg = c.cream }, ["@string.escape"] = { fg = c.apricot },
        ["@number"] = { fg = c.apricot }, ["@boolean"] = { fg = c.apricot },
        ["@constant"] = { fg = c.apricot }, ["@function"] = { fg = c.brown },
        ["@function.call"] = { fg = c.brown }, ["@method"] = { fg = c.brown },
        ["@variable"] = { fg = c.cream }, ["@variable.builtin"] = { fg = c.cream },
        ["@type"] = { fg = c.brown }, ["@constructor"] = { fg = c.brown },
        ["@include"] = { fg = c.brown }, ["@punctuation"] = { fg = c.stone },
        ["@tag"] = { fg = c.brown }, ["@tag.attribute"] = { fg = c.apricot },
        ["@markup.heading"] = { fg = c.apricot, bold = true },
        ["@markup.link"] = { fg = c.apricot, underline = true },
        ["@markup.raw"] = { fg = c.cream }, ["@error"] = { fg = c.terracotta, bold = true },
      }
      for group, opts in pairs(treesitter) do hl(group, opts) end

      hl("DiffAdd", { fg = c.brown, bg = "none" })
      hl("DiffChange", { fg = c.apricot, bg = "none" })
      hl("DiffDelete", { fg = c.terracotta, bg = "none" })
      hl("DiffText", { fg = c.cream, bg = "none" })
      hl("DiagnosticError", { fg = c.terracotta })
      hl("DiagnosticWarn", { fg = c.apricot })
      hl("DiagnosticInfo", { fg = c.cream })
      hl("DiagnosticHint", { fg = c.stone })
      hl("DiagnosticOk", { fg = c.brown })
      hl("SignColumn", { bg = "none" })
    end
    return M
  '';
in
{
  home.packages = [ pkgs.neovim ];
  home.sessionVariables = {
    EDITOR = "${pkgs.neovim}/bin/nvim";
    VISUAL = "${pkgs.neovim}/bin/nvim";
  };
  # HM backs up the former unmanaged file using the configured backup suffix.
  xdg.configFile."nvim/lua/p10k.lua".source = themeModule;
}
