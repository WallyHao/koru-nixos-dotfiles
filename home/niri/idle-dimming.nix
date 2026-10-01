# Dim idle displays, preserve manual brightness and power off idle monitors.
{ lib, pkgs, ... }:
let
  brightnessctl = lib.getExe pkgs.brightnessctl;
  niri = lib.getExe pkgs.niri;
  dim-display = pkgs.writeShellScript "dim-idle-display" ''
    set -eu
    # brightnessctl saves the raw value for this user's backlight device.
    # Restrict the device class so keyboard/indicator LEDs are never selected.
    current=$(${brightnessctl} --class=backlight --save get)
    maximum=$(${brightnessctl} --class=backlight max)
    target=$((maximum / 10))
    [ "$target" -ge 1 ] || target=1

    # An already dim display must not become brighter on idle.
    if [ "$current" -gt "$target" ]; then
      ${brightnessctl} --class=backlight set "$target"
    fi
  '';
in
{
  # Save/dim after 5 min, power off all monitors after 10 min total inactivity.
  # On activity, restore the saved brightness and turn monitors back on.
  # The module's default -w serializes commands, including save before restore.
  # This user service is bound to graphical-session.target via niri.service.
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "${dim-display}";
        resumeCommand = "${brightnessctl} --class=backlight --restore";
      }
      {
        timeout = 600;
        command = "${niri} msg action power-off-monitors";
        resumeCommand = "${niri} msg action power-on-monitors";
      }
    ];
  };

}
