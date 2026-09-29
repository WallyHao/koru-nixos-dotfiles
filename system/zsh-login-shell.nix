# --- shell ---
# Login shell interpreter (system side). Enabled at the machine layer, not in
# the host file, so every device shares it; the interactive config (p10k,
# plugins, aliases) is the user layer in home/zsh.nix. Keeping the
# interpreter here means a TTY login has a working shell with no home-manager
# generation active.
{
  programs.zsh.enable = true;
}
