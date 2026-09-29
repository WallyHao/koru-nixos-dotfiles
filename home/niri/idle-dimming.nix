# Dim idle displays and restore the AC/battery profile.
{ lib, pkgs, ... }:
let
  brightnessctl = lib.getExe pkgs.brightnessctl;
  power-profile = "/run/current-system/sw/bin/power-profile";
in
{
  # Dim to 10% after 5 min of inactivity (swayidle as a systemd user service,
  # bound by default to graphical-session.target, which niri.service pulls in);
  # restore goes through power-profile: 60% on battery / 100% on AC.
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "${brightnessctl} set 10%";
        resumeCommand = power-profile;
      }
    ];
  };

}
