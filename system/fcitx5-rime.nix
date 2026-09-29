# --- input-method ---
# Fcitx5 input method framework (system side: engine + install + IM env vars).
# The Chinese engine is Rime with the rime-ice scheme; per-user theme, profile
# and Rime config live in home/fcitx5.nix.
{ pkgs, ... }:

{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      # Rime engine; rime-ice (Wu Song) becomes its shared data dir, so no
      # GitHub fetch or manual dictionary copying is needed at runtime.
      (fcitx5-rime.override { rimeDataPkgs = [ rime-ice ]; })
      fcitx5-gtk
      qt6Packages.fcitx5-configtool
    ];
  };

  environment.variables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
  };
}
