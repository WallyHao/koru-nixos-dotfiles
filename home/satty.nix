# --- satty ---
# Screenshot annotation tool (replaces swappy). Colors/font come from the
# global theme (system/theme.nix). Satty's window chrome is GTK4/Adwaita, so a CSS
# override is used to apply the dark Koru Fern palette instead of stock Adwaita.
{ pkgs, theme, ... }:
let
  # Satty's palette wants #RRGGBBAA; theme colors have no alpha channel.
  rgba = c: "${c}FF";
in
{
  home.packages = [ pkgs.satty ];

  xdg.configFile."satty/config.toml".text = ''
    [general]
    initial-tool = "brush"
    copy-command = "wl-copy"
    output-filename = "~/Pictures/Screenshots/satty-%Y%m%d-%H%M%S.png"
    annotation-size-factor = 1.5
    floating-hack = true
    corner-roundness = 8
    no-window-decoration = true
    actions-on-enter = ["save-to-clipboard", "save-to-file", "exit"]
    actions-on-escape = ["exit"]
    actions-on-right-click = ["save-to-clipboard"]

    [font]
    family = "${theme.font}"
    style = "Regular"

    [color-palette]
    palette = [
      "${rgba theme.accent}",
      "${rgba theme.ansi.red}",
      "${rgba theme.ansi.green}",
      "${rgba theme.ansi.yellow}",
      "${rgba theme.ansi.blue}",
      "${rgba theme.ansi.magenta}",
      "${rgba theme.ansi.cyan}",
      "${rgba theme.fg}",
      "${rgba theme.urgent}",
    ]
  '';

  # GTK4/Adwaita chrome (toolbars, headerbar, image letterbox). Satty loads
  # this after its builtin CSS, so these values win.
  xdg.configFile."satty/overrides.css".text = ''
    @define-color headerbar_bg_color ${theme.bg};
    @define-color headerbar_fg_color ${theme.fg};
    @define-color accent_color ${theme.accent};

    .outer_box,
    .toolbar {
      color: ${theme.fg};
      background-color: ${theme.bg};
    }

    .inner_box {
      background-color: ${theme.bg};
    }

    button {
      color: ${theme.fg};
      background-color: ${theme.bg-alt};
      border-color: ${theme.border};
    }

    button:hover {
      background-color: ${theme.accent-bg};
    }

    button:checked,
    button:active {
      color: ${theme.black};
      background-color: ${theme.accent};
    }

    button.editing {
      color: ${theme.accent};
    }

    .toast {
      color: ${theme.fg};
      background-color: ${theme.black};
      border-radius: 6px;
    }
  '';
}
