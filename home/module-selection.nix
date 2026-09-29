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
    c-cpp-toolchain = true;
    codex = true;
    cursor-theme = true;
    eza = true;
    fastfetch = true;
    fcitx5 = true;
    fd = true;
    fzf = true;
    gh = true;
    git = true;
    gtk = true;
    imv = true;
    java-toolchain = true;
    jq = true;
    just = true;
    libreoffice = true;
    neovim = true;
    niri = true;
    nodejs = true;
    opencode = true;
    openmpi = true;
    poppler-utils = true;
    ripgrep = true;
    ros2 = true;
    ruff = true;
    rust = true;
    satty = true;
    tty-login = true;
    typst = true;
    unrar = true;
    unzip = true;
    uv = true;
    zathura = true;
    zen-browser = true;
    zoxide = true;
    zsh = true;
  };
}
