# --- bluetooth ---
# Bluetooth is off: the stack is not enabled and the radio is soft-blocked.
# The Logitech 2.4G mouse means the radio is never used.
{ pkgs, ... }:

{
  # --- Bluetooth: disabled ---
  hardware.bluetooth.enable = false;
  services.blueman.enable = false;

  # btusb may still probe the controller, so keep it rfkill-blocked for battery
  # life. To use Bluetooth, re-enable the stack first (hardware.bluetooth.enable),
  # then: rfkill unblock bluetooth && bluetoothctl power on
  systemd.services.block-bluetooth = {
    description = "Block Bluetooth rfkill (power saving)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-rfkill.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill block bluetooth";
    };
  };
}
