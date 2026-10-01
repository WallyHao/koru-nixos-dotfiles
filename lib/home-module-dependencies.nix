# Direct command/configuration dependencies between optional Home Manager
# modules. Keeping this data separate makes invalid switch combinations fail
# with a clear message instead of silently re-enabling software.
{
  fzf = [
    "fd"
    "zsh"
  ];
  niri = [
    "alacritty"
    "btop"
    "clipboard-history"
    "fcitx5"
    "imv"
    "satty"
    "zen-browser"
  ];
  tty-login = [
    "niri"
    "zsh"
  ];
  zsh = [
    "bat"
    "eza"
    "fzf"
    "libreoffice"
    "zen-browser"
  ];
}
