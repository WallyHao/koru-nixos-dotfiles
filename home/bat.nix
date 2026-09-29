# --- bat ---
# cat with syntax highlighting + git changes. `theme = "ansi"` reuses the
# terminal's 16 ANSI colors, which are already the Koru Fern palette, so it
# stays in sync with system/theme.nix for free. Aliases (cat/catp) live in zsh.nix.
_: {
  programs.bat = {
    enable = true;
    config = {
      theme = "ansi";
      style = "numbers,changes,header";
    };
  };
}
