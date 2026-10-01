# --- opencode ---
# AI coding agent, installed from the opencode flake input. The global
# AGENTS.md lives in home/dotfiles/opencode/ and is linked into
# ~/.config/opencode/ so the repo stays the source of truth.
{
  inputs,
  pkgs,
  theme,
  ...
}:
let
  # OpenCode's current TUI reads a named theme from tui.json and loads the
  # matching file from ~/.config/opencode/themes/. Keep both files generated
  # from the shared palette so the theme cannot silently fall back to default.
  variant = color: {
    dark = color;
    light = color;
  };

  opencodeTheme = {
    "$schema" = "https://opencode.ai/theme.json";
    theme = {
      primary = variant theme.accent;
      secondary = variant theme.accent-yellow;
      accent = variant theme.accent-yellow;
      error = variant theme.ansi.red;
      warning = variant theme.accent-yellow;
      success = variant theme.accent-bright;
      info = variant theme.ansi.cyan;
      text = variant theme.fg;
      textMuted = variant theme.muted;
      background = variant theme.bg;
      backgroundPanel = variant theme.bg-alt;
      backgroundElement = variant theme.bg-alt;
      border = variant theme.border;
      borderActive = variant theme.accent-yellow;
      borderSubtle = variant theme.border;
      diffAdded = variant theme.accent-bright;
      diffRemoved = variant theme.ansi-bright.red;
      diffContext = variant theme.muted-alt;
      diffHunkHeader = variant theme.accent-yellow;
      diffHighlightAdded = variant theme.accent-yellow-bright;
      diffHighlightRemoved = variant theme.ansi-bright.red;
      diffAddedBg = variant theme.accent-bg;
      diffRemovedBg = variant "#4A2F34";
      diffContextBg = variant theme.bg-alt;
      diffLineNumber = variant theme.muted-alt;
      diffAddedLineNumberBg = variant theme.accent-bg;
      diffRemovedLineNumberBg = variant "#4A2F34";
      markdownText = variant theme.fg;
      markdownHeading = variant theme.accent-yellow;
      markdownLink = variant theme.ansi.blue;
      markdownLinkText = variant theme.accent;
      markdownCode = variant theme.accent-bright;
      markdownBlockQuote = variant theme.muted;
      markdownEmph = variant theme.accent-yellow;
      markdownStrong = variant theme.accent-yellow-bright;
      markdownHorizontalRule = variant theme.border;
      markdownListItem = variant theme.accent;
      markdownListEnumeration = variant theme.accent-yellow;
      markdownImage = variant theme.ansi.magenta;
      markdownImageText = variant theme.accent-yellow;
      markdownCodeBlock = variant theme.fg;
      syntaxComment = variant theme.muted-alt;
      syntaxKeyword = variant theme.accent-yellow;
      syntaxFunction = variant theme.accent;
      syntaxVariable = variant theme.accent-yellow-bright;
      syntaxString = variant theme.accent-bright;
      syntaxNumber = variant theme.ansi.magenta;
      syntaxType = variant theme.ansi.blue;
      syntaxOperator = variant theme.ansi.cyan;
      syntaxPunctuation = variant theme.fg;
    };
  };
in
{
  home.packages = [
    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  home.file.".config/opencode/AGENTS.md".source = ./dotfiles/opencode/AGENTS.md;

  # OpenCode loads both tui.json and tui.jsonc and applies them in that order,
  # so the later tui.jsonc wins. Generate the .jsonc name so this managed file
  # always beats a leftover/global tui.json (a stale tui.jsonc otherwise
  # silently overrides the selection). opencode.json alone is ignored for TUI.
  xdg.configFile."opencode/tui.jsonc".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "koru-fern";
  };

  xdg.configFile."opencode/themes/koru-fern.json".text = builtins.toJSON opencodeTheme;

  # Ensure OpenCode and other terminal UIs use the full 24-bit palette.
  home.sessionVariables.COLORTERM = "truecolor";
}
