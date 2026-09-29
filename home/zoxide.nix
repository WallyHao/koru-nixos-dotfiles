# --- zoxide ---
# Smarter `cd` history. Replaces oh-my-zsh's `z` plugin (removed in zsh.nix);
# provides z/zi. `--cmd cd` is intentionally NOT set: plain `cd` keeps its
# normal meaning, use `z <fragment>` to jump.
_: {
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
