# Started only by koru click; stop when the graphical session ends.
{ pkgs, ... }:
{
  systemd.user.services.koru-click = {
    Unit = {
      Description = "Koru automatic left mouse clicks";
      PartOf = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.python3}/bin/python3 ${../../scripts/koru/click.py} --worker";
      Environment = "YDOTOOL_SOCKET=/run/ydotoold/socket";
      TimeoutStopSec = 2;
    };
  };
}
