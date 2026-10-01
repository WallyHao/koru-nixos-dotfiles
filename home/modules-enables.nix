# --- enabled ---
# The single software switchboard for the user layer: one boolean per home
# module, which is also the inventory of what home/ can install.
#
#   enable: true installs the module (package + its config), false keeps the
#           file in the repo unused. One boolean, one question: installed or
#           not.
#
# The keys must match the home/ module files exactly in both directions
# (asserted in home/default.nix). So a new module that is not listed here, or a
# flag with no file, fails evaluation instead of being dropped silently.
{
  enable = {
    alacritty = true;
    bat = true;
    btop = true;
    chsrc = true;
    clipboard-history = true;
    codex = true;
    cursor-theme = true;
    drawio = true;
    eza = true;
    fastfetch = true;
    fcitx5 = true;
    fd = true;
    fzf = true;
    gh = true;
    git = true;
    gtk = true;
    imv = true;
    jq = true;
    kitty = true;
    libreoffice = true;
    neovim = true;
    niri = true;
    opencode = true;
    poppler-utils = true;
    ripgrep = true;
    satty = true;
    tty-login = true;
    unrar = true;
    unzip = true;
    zathura = true;
    zen-browser = true;
    zoxide = true;
    zsh = true;
  };
}
