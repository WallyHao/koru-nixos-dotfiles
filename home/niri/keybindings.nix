# Niri keyboard bindings; pure settings data, not a Home Manager module.
{
  lib,
  pkgs,
  modifier,
  menu,
  brightnessctl,
  enabled,
}:
let
  optionalBindings = {
    "${modifier}+Return" = "kitty";
    "${modifier}+l" = "zen-browser";
    "${modifier}+i" = "imv";
    "${modifier}+v" = "clipboard-history";
    "${modifier}+s" = "satty";
    "${modifier}+Shift+s" = "satty";
  };
in
lib.filterAttrs
  (name: _: !(optionalBindings ? ${name}) || (enabled.enable.${optionalBindings.${name}} or false))
  {
    # Launch
    "${modifier}+Return" = {
      spawn = [ "kitty" ];
    };
    "${modifier}+l" = {
      spawn = [ "zen-beta" ];
    };
    "${modifier}+d" = {
      spawn = [ menu ];
    };
    # Image viewer on the Pictures folder (theme/config in home/imv.nix).
    # spawn-sh so $HOME expands; the rest of imv is driven from its own keys.
    "${modifier}+i" = {
      spawn-sh = "imv \"$HOME/Pictures\"";
    };

    # Toggle once per key press, including while stopping an active clicker.
    "${modifier}+c" = {
      _props.repeat = false;
      spawn = [
        "koru"
        "click"
        "toggle"
      ];
    };

    # Window control
    "${modifier}+q" = {
      close-window = { };
    };
    "${modifier}+Shift+e" = {
      quit = { };
    };
    "${modifier}+f" = {
      fullscreen-window = { };
    };
    # Widen the column to the available width without going fullscreen
    # (gaps and border stay). Undo with Alt+r/Alt+minus.
    "${modifier}+Shift+f" = {
      expand-column-to-available-width = { };
    };

    # Overview: the same thing the top-left hot corner opens. repeat=false
    # so holding the key doesn't flicker it. While it is open the focus-*
    # binds below move the viewport, and this bind closes it again. Tab is
    # niri's unbound default slot, so this overrides no built-in bind.
    "${modifier}+Tab" = {
      _props.repeat = false;
      toggle-overview = { };
    };

    # Session control
    # Lock the session. swaylock's PAM service is provided by niri's
    # wayland-session.nix, so no system change is needed.
    "${modifier}+Shift+l" = {
      spawn = [ (lib.getExe pkgs.swaylock) ];
    };
    "${modifier}+Shift+r" = {
      spawn = [
        "systemctl"
        "reboot"
      ];
    };
    "${modifier}+Shift+t" = {
      spawn = [
        "systemctl"
        "poweroff"
      ];
    };

    # Focus movement: left/right move between columns, up/down between
    # windows in a column (niri's scrolling layout).
    "${modifier}+Left" = {
      focus-column-left = { };
    };
    "${modifier}+Right" = {
      focus-column-right = { };
    };
    "${modifier}+Up" = {
      focus-window-up = { };
    };
    "${modifier}+Down" = {
      focus-window-down = { };
    };

    # Move the focused window/column towards that neighbour.
    "${modifier}+Shift+Left" = {
      move-column-left = { };
    };
    "${modifier}+Shift+Right" = {
      move-column-right = { };
    };
    "${modifier}+Shift+Up" = {
      move-window-up = { };
    };
    "${modifier}+Shift+Down" = {
      move-window-down = { };
    };

    # Fine width/height adjustments (was 10px in sway; percentages scale).
    "${modifier}+equal" = {
      set-column-width = "+10%";
    };
    "${modifier}+minus" = {
      set-column-width = "-10%";
    };
    "${modifier}+Shift+equal" = {
      set-window-height = "+10%";
    };
    "${modifier}+Shift+minus" = {
      set-window-height = "-10%";
    };

    # Cycle the preset column widths (1/2 -> 1/4 -> 3/4).
    "${modifier}+r" = {
      switch-preset-column-width = { };
    };

    # Workspaces: switch + move. "scratch" is slot 0 (named workspace
    # above), so the numbered workspaces sit at positions 2..10.
    "${modifier}+0" = {
      focus-workspace = "scratch";
    };
    "${modifier}+1" = {
      focus-workspace = 2;
    };
    "${modifier}+2" = {
      focus-workspace = 3;
    };
    "${modifier}+3" = {
      focus-workspace = 4;
    };
    "${modifier}+4" = {
      focus-workspace = 5;
    };
    "${modifier}+5" = {
      focus-workspace = 6;
    };
    "${modifier}+6" = {
      focus-workspace = 7;
    };
    "${modifier}+7" = {
      focus-workspace = 8;
    };
    "${modifier}+8" = {
      focus-workspace = 9;
    };
    "${modifier}+9" = {
      focus-workspace = 10;
    };
    "${modifier}+Shift+0" = {
      move-column-to-workspace = "scratch";
    };
    "${modifier}+Shift+1" = {
      move-column-to-workspace = 2;
    };
    "${modifier}+Shift+2" = {
      move-column-to-workspace = 3;
    };
    "${modifier}+Shift+3" = {
      move-column-to-workspace = 4;
    };
    "${modifier}+Shift+4" = {
      move-column-to-workspace = 5;
    };
    "${modifier}+Shift+5" = {
      move-column-to-workspace = 6;
    };
    "${modifier}+Shift+6" = {
      move-column-to-workspace = 7;
    };
    "${modifier}+Shift+7" = {
      move-column-to-workspace = 8;
    };
    "${modifier}+Shift+8" = {
      move-column-to-workspace = 9;
    };
    "${modifier}+Shift+9" = {
      move-column-to-workspace = 10;
    };

    # Media keys (allow-when-locked so they keep working at the locker).
    "XF86AudioMute" = {
      _props.allow-when-locked = true;
      spawn = [
        "wpctl"
        "set-mute"
        "@DEFAULT_AUDIO_SINK@"
        "toggle"
      ];
    };
    "XF86AudioRaiseVolume" = {
      _props.allow-when-locked = true;
      spawn = [
        "wpctl"
        "set-volume"
        "@DEFAULT_AUDIO_SINK@"
        "5%+"
      ];
    };
    "XF86AudioLowerVolume" = {
      _props.allow-when-locked = true;
      spawn = [
        "wpctl"
        "set-volume"
        "@DEFAULT_AUDIO_SINK@"
        "5%-"
      ];
    };
    "XF86AudioPlay" = {
      _props.allow-when-locked = true;
      spawn = [
        "playerctl"
        "play-pause"
      ];
    };
    "XF86AudioNext" = {
      _props.allow-when-locked = true;
      spawn = [
        "playerctl"
        "next"
      ];
    };
    "XF86AudioPrev" = {
      _props.allow-when-locked = true;
      spawn = [
        "playerctl"
        "previous"
      ];
    };
    "XF86MonBrightnessUp" = {
      spawn = [
        brightnessctl
        "set"
        "+5%"
      ];
    };
    "XF86MonBrightnessDown" = {
      spawn = [
        brightnessctl
        "set"
        "5%-"
      ];
    };
    # Keyboard fallback (the media keys above don't fire on this keyboard).
    "${modifier}+F5" = {
      spawn = [
        brightnessctl
        "set"
        "5%-"
      ];
    };
    "${modifier}+F6" = {
      spawn = [
        brightnessctl
        "set"
        "+5%"
      ];
    };

    # Clipboard history picker (history/persistence daemons and the
    # cliphist-pick script live in home/clipboard-history.nix).
    "${modifier}+v" = {
      spawn = [ "cliphist-pick" ];
    };

    # Screenshots (annotate in satty; config/theming in home/satty.nix).
    # Pipes need a shell, hence spawn-sh.
    "${modifier}+s" = {
      spawn-sh = "grim -t ppm - | satty --filename -";
    };
    "${modifier}+Shift+s" = {
      spawn-sh = "grim -g \"$(slurp)\" -t ppm - | satty --filename -";
    };
  }
