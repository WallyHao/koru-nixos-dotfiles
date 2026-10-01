# --- niri ---
# Compositor config, generated declaratively by home-manager's
# wayland.windowManager.niri module (typed KDL via `settings`). All colors and
# fonts reference the global theme (system/theme.nix). The frecency launcher
# (wmenu-frecency), idle dimming and keybindings live under home/niri/.
#
# Niri is a scrollable-tiling compositor, so the old sway helpers are gone:
# window swapping/resizing and the width presets are built-in actions, and
# autotiling is unnecessary. The compositor itself is installed at the system
# layer (system/niri-session.nix), which also provides niri.service for
# niri-session, so package/systemd are disabled here to avoid double-starting.
{
  lib,
  pkgs,
  theme,
  enabled,
  ...
}:
let
  # niri spells the Alt modifier "Alt" (there is no Mod1); niri's own "Mod"
  # alias would map to Super on a TTY.
  modifier = "Alt";
  power-profile = "/run/current-system/sw/bin/power-profile";
  proxyctl = "/run/current-system/sw/bin/proxyctl";
  brightnessctl = lib.getExe pkgs.brightnessctl;
  menu = "wmenu-frecency";
in
{
  imports = [
    ./niri/application-launcher.nix
    ./niri/idle-dimming.nix
  ];

  # The frecency launcher is a hard dependency of this config, so it ships with
  # niri rather than being an optional module group.
  home.packages = with pkgs; [
    # Explicit pkgs. prefix: the let-binding above shadows `brightnessctl`.
    pkgs.brightnessctl
    playerctl
    grim
    slurp
    wl-clipboard
  ];

  # --- Compositor config ---
  wayland.windowManager.niri = {
    enable = true;

    # Installed at the system layer (system/niri-session.nix, programs.niri), which
    # also wires the session/portal plumbing and niri.service; leaving this null
    # avoids a duplicate niri in the user profile.
    package = null;
    systemd.enable = false;
    portalPackage = null;

    settings = {
      # No CSD: the sway config had titlebar=false.
      prefer-no-csd = { };
      # The sway config had no hotkey overlay; don't show one at startup.
      hotkey-overlay.skip-at-startup = { };

      # The backdrop is the color niri draws between workspaces (and behind the
      # overview). The workspace background is theme.bg, so match it to hide the
      # seam. This is the global form (covers every monitor), unlike the
      # per-output backdrop-color which needs an exact output name.
      overview = {
        backdrop-color = theme.bg;
      };

      # Cursor: the single definition is theme.cursor-name/-size (home/cursor-theme.nix
      # recolors it and sets the GTK side; XCURSOR_THEME reaches niri's children
      # through home.sessionVariables).
      cursor = {
        xcursor-theme = theme.cursor-name;
        xcursor-size = theme.cursor-size;
      };

      input = {
        keyboard.xkb.layout = "us";
        touchpad = {
          tap = { };
          natural-scroll = { };
        };
      };

      layout = {
        # sway used inner 8 / outer 4 (top 16). niri gaps are inner+outer, so
        # positive/negative struts trim the sides and keep the top margin.
        # Effective top margin = gaps + struts.top (8 + 16 = 24 here); raise
        # struts.top for more headroom.
        gaps = 8;
        struts = {
          top = 16;
          left = -4;
          right = -4;
          bottom = -4;
        };

        background-color = theme.bg;

        # sway: always-visible 2px border, accent when focused.
        focus-ring.off = { };
        border = {
          on = { };
          width = 2;
          active-color = theme.accent-yellow;
          inactive-color = theme.border;
          urgent-color = theme.urgent;
        };

        # sway cycled 1/2 -> 1/4 -> 3/4 of the workspace; niri cycles a preset
        # list (Alt+r), so list them in that order.
        preset-column-widths._children = [
          { proportion = 0.5; }
          { proportion = 0.25; }
          { proportion = 0.75; }
        ];
      };

      # A single workspace ("scratch") holds the startup dashboard. fastfetch
      # opens first and btop opens second, so niri keeps fastfetch on btop's
      # left; btop keeps its full-width column. Named workspaces avoid relying
      # on numeric workspace positions while the desktop is still being
      # assembled.
      #
      # Optional dashboard entries follow their software switches.
      # Startup entries. Proxy bootstrap runs in the background without a
      # window, so it neither steals focus nor adds a report column.
      _children = [
        { workspace._args = [ "scratch" ]; }
        { spawn-at-startup = [ power-profile ]; }
        {
          spawn-at-startup = [
            proxyctl
            "autostart"
          ];
        }
      ]
      ++ lib.optionals (enabled.enable.fcitx5 or false) [
        {
          spawn-at-startup = [
            "fcitx5"
            "-d"
          ];
        }
      ]
      ++
        lib.optionals
          (
            (enabled.enable.kitty or false)
            && (enabled.enable.fastfetch or false)
            && (enabled.enable.zsh or false)
          )
          [
            {
              window-rule._children = [
                { match._props.app-id = "(?i)^koru-fetch$"; }
                { open-on-workspace = "scratch"; }
                { default-column-width._children = [ { proportion = 0.5; } ]; }
              ];
            }
            {
              spawn-at-startup = [
                "kitty"
                "--class"
                "koru-fetch"
                "-e"
                "zsh"
                "-lc"
                "fastfetch; exec zsh -i"
              ];
            }
          ]
      ++ lib.optionals ((enabled.enable.kitty or false) && (enabled.enable.btop or false)) [
        {
          window-rule._children = [
            { match._props.app-id = "(?i)^btop$"; }
            { open-on-workspace = "scratch"; }
            { default-column-width._children = [ { proportion = 1.0; } ]; }
          ];
        }
        {
          spawn-at-startup = [
            "kitty"
            "--class"
            "btop"
            "-e"
            "btop"
          ];
        }
      ]
      ++ [
        {
          spawn-at-startup = [
            "niri"
            "msg"
            "action"
            "focus-workspace"
            "scratch"
          ];
        }
      ];

      binds = import ./niri/keybindings.nix {
        inherit
          lib
          pkgs
          modifier
          menu
          brightnessctl
          enabled
          ;
      };
    };
  };
}
