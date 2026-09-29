# --- GTK ---
# Makes GTK apps match the global theme (system/theme.nix).
#
# GTK3: the xdg-desktop-portal-gtk "Save As" file chooser (and other GTK3
#   apps) use adw-gtk3-dark. adw-gtk3 is a port of Adwaita and reads the
#   libadwaita named colors (not the legacy @theme_* names), so those are what
#   we override; the legacy names are kept too for older widgets.
# GTK4/libadwaita: ignores the theme name, so dark mode is set through GTK4's
#   native gtk-interface-color-scheme and re-coloured with the same libadwaita
#   named colors.
{
  pkgs,
  lib,
  theme,
  ...
}:
let
  # libadwaita named colors, used by both adw-gtk3 (GTK3) and GTK4.
  colors = ''
    @define-color accent_color ${theme.accent};
    @define-color accent_bg_color ${theme.accent};
    @define-color accent_fg_color ${theme.black};
    @define-color window_bg_color ${theme.bg};
    @define-color window_fg_color ${theme.fg};
    @define-color view_bg_color ${theme.bg};
    @define-color view_fg_color ${theme.fg};
    @define-color headerbar_bg_color ${theme.bg};
    @define-color headerbar_fg_color ${theme.fg};
    @define-color sidebar_bg_color ${theme.bg-alt};
    @define-color sidebar_fg_color ${theme.fg};
    @define-color card_bg_color ${theme.bg-alt};
    @define-color card_fg_color ${theme.fg};
    @define-color dialog_bg_color ${theme.bg};
    @define-color dialog_fg_color ${theme.fg};
    @define-color popover_bg_color ${theme.bg-alt};
    @define-color popover_fg_color ${theme.fg};
    @define-color borders ${theme.border};
  '';

  # Pre-libadwaita GTK3 names (still used by a few widgets/apps).
  legacy = ''
    @define-color theme_bg_color ${theme.bg};
    @define-color theme_fg_color ${theme.fg};
    @define-color theme_base_color ${theme.bg};
    @define-color theme_text_color ${theme.fg};
    @define-color theme_selected_bg_color ${theme.accent};
    @define-color theme_selected_fg_color ${theme.black};
    @define-color theme_unfocused_bg_color ${theme.bg};
    @define-color theme_unfocused_fg_color ${theme.muted};
  '';

  # Square corners + a 2px accent outline so GTK windows match niri's borders
  # (niri: layout.border width 2, active-color = theme.accent in home/niri.nix).
  extras = ''
    window,
    window.background,
    headerbar,
    .titlebar,
    popover,
    popover.background,
    menu,
    tooltip,
    dialog,
    messagedialog,
    decoration {
      border-radius: 0;
    }

    /* GTK3 CSD outline */
    decoration {
      border: 2px solid ${theme.accent};
      box-shadow: none;
    }

    /* GTK4/libadwaita CSD outline */
    window.csd {
      border: 2px solid ${theme.accent};
      border-radius: 0;
      box-shadow: none;
    }
  '';
in
{
  gtk = {
    enable = true;
    colorScheme = "dark";

    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    font = {
      name = theme.font;
      size = theme.font-size-ui;
    };

    # Cursor theme is defined once in home/cursor-theme.nix
    # (home.pointerCursor.gtk.enable) and injected here by home-manager.

    gtk3.extraCss = colors + legacy + extras;
    gtk4.extraCss = colors + extras;

    # GTK4 dark mode, done the native way. home-manager otherwise writes
    #   gtk-application-prefer-dark-theme=true (libadwaita warns about it) and
    #   gtk-interface-color-scheme=2 (GTK can't parse the integer from
    #   settings.ini). GTK4's own key is the enum *nick* "dark".
    gtk4.colorScheme = null;
    gtk4.extraConfig."gtk-interface-color-scheme" = "dark";
  };

  # The GTK3 "Save As" chooser (xdg-desktop-portal-gtk) persists its window
  # size in dconf. Shrink the default height a bit.
  dconf.enable = true;
  dconf.settings."org/gtk/settings/file-chooser".window-size = lib.hm.gvariant.mkTuple [
    1231
    720
  ];
}
