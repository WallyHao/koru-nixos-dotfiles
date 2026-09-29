# Niri display brightness and refresh-rate policy on AC/battery.
{
  lib,
  pkgs,
  username,
  ...
}:
let
  # Store paths kept out of the ambient PATH (udev spawns power-profile with no
  # user environment).
  jq = lib.getExe pkgs.jq;
  niri = lib.getExe pkgs.niri;

  # AC/battery screen profile: dim to 60% + 60Hz on battery, full 100% + 144Hz
  # on AC. No-ops unless a niri session is running, so it is safe as a udev
  # trigger.
  power-profile = pkgs.writeShellScriptBin "power-profile" ''
    set -euo pipefail
    export PATH=/run/current-system/sw/bin

    uid="''$(id -u)"
    export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/''$uid}"

    # niri's IPC socket lives in XDG_RUNTIME_DIR, but udev starts us without the
    # session environment, so recover it from the socket file (the old sway
    # script did the same for SWAYSOCK).
    if [ -z "''${NIRI_SOCKET:-}" ]; then
      for sock in /run/user/''$uid/niri*.sock; do
        [ -S "''$sock" ] && { NIRI_SOCKET="''$sock"; break; }
      done
    fi
    [ -z "''${NIRI_SOCKET:-}" ] && exit 0
    export NIRI_SOCKET

    on_battery=false
    for status in /sys/class/power_supply/*/status; do
      if [ -r "''$status" ] && [ "$(cat "''$status")" = "Discharging" ]; then
        on_battery=true
        break
      fi
    done

    # The active output is the one with a logical mapping (a disabled output has
    # none), so no connector is hardcoded.
    output=$(${niri} msg --json outputs | ${jq} -r '
      to_entries | map(select(.value.logical != null)) | .[0].key // empty
    ')
    [ -n "$output" ] || exit 0

    # Pick the 1920x1080 mode whose refresh is closest to the target. niri needs
    # the exact mode string while its IPC reports refresh in millihertz, so
    # format it back to Hz here.
    pick_mode() {
      ${niri} msg --json outputs | ${jq} -r --arg o "$output" --argjson hz "$1" '
        (.[$o].modes
          | map(select(.width == 1920 and .height == 1080))
          | sort_by(((.refresh_rate / 1000) - $hz) | if . < 0 then -. else . end)
          | .[0]) as $best
        | if $best == null then empty
          else "\($best.width)x\($best.height)@\($best.refresh_rate / 1000)" end
      '
    }

    if [ "$on_battery" = true ]; then
      brightnessctl set 60%
      mode=$(pick_mode 60)
    else
      brightnessctl set 100%
      mode=$(pick_mode 144)
    fi
    [ -n "$mode" ] && [ "$mode" != "null" ] && ${niri} msg output "$output" mode "$mode"
  '';
in
{
  environment.systemPackages = [
    power-profile
    pkgs.brightnessctl
  ];

  # --- Screen power profile ---
  # udev must return promptly: queue work in systemd rather than running
  # compositor IPC and display changes in the device event worker.
  systemd.services.niri-display-power = {
    description = "Apply Niri display power profile";
    serviceConfig = {
      Type = "oneshot";
      User = username;
      ExecStart = "${power-profile}/bin/power-profile";
    };
  };
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl --no-block start niri-display-power.service"
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl --no-block start niri-display-power.service"
  '';
}
