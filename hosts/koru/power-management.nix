# --- power ---
# Power saving: auto-cpufreq (AC/battery CPU scaling), thermald, upower, audio
# codec power save and powertop auto-tune at boot.
# Compressed swap and VM tuning live in memory-zram.nix.
#
# Refs:
#   - auto-cpufreq profile: nyx (laptop/system/power/monitors/auto-cpufreq.nix)
#   - caution: on some boards `powersave` pins cores at the frequency floor
#     (Misterio77's merope stall); keep EPP + a max-freq cap, no hard min.
#   - VM tuning: pop-os default-settings, also used by nyx and ryan4yin.
{ lib, pkgs, ... }:
let
  # Pin the Logitech 2.4G receiver (046d:c53f) to "on" so the mouse never gets
  # autosuspended (autosuspend makes the first movement lag on wake).
  keep-mouse-awake = pkgs.writeShellScript "keep-mouse-awake" ''
    for d in /sys/bus/usb/devices/*; do
      [ -r "$d/idVendor" ] || continue
      [ "$(cat "$d/idVendor"):$(cat "$d/idProduct")" = "046d:c53f" ] || continue
      echo on > "$d/power/control"
    done
  '';
in
{
  environment.systemPackages = with pkgs; [
    powertop
    powerstat
    pciutils
  ];

  # --- CPU frequency scaling ---
  # Replaces power-profiles-daemon (they fight over the governor): on battery
  # cores stay low with turbo off; on charger everything runs all-out.
  # i7-13650HX: 800MHz floor, 4.7GHz ceiling, HWP EPP supported.
  services.auto-cpufreq = {
    enable = true;
    settings = {
      charger = {
        governor = "performance";
        energy_performance_preference = "performance";
        turbo = "auto";
      };
      battery = {
        governor = "powersave";
        energy_performance_preference = "power";
        # Cap P-core bursts at 3GHz on battery (~30% less peak power draw);
        # idle still drops to the 800MHz floor (no hard min, see header ref).
        scaling_max_freq = "3000000";
        turbo = "never";
      };
    };
  };

  # --- Thermal ---
  # Intel DPTF daemon: smooths fans and clock throttling under sustained load;
  # pairs with the already-active Intel microcode updates.
  #
  # The NixOS module hardcodes --adaptive, but this board exposes no DPTF/PSVT
  # performance tables, so adaptive mode finds no zones and exits 1, which
  # systemd flags at every boot. Drop the flag: non-adaptive is thermald's own
  # suggested fallback and works off the standard thermal zones.
  services.thermald.enable = true;
  systemd.services.thermald.serviceConfig.ExecStart =
    lib.mkForce "${pkgs.thermald}/sbin/thermald --no-daemon --dbus-enable";

  # --- Battery reporting ---
  # upower powers battery UI and AC/battery events (auto-cpufreq and the screen
  # profile in hosts/koru/display-power.nix both listen for them).
  services.upower.enable = true;

  # --- Audio codec ---
  # Power save from module load time (powertop re-applies it at runtime).
  boot.extraModprobeConfig = "options snd_hda_intel power_save=1";

  # --- Powertop ---
  # auto-tune at boot: USB autosuspend, PCIe runtime PM (NIC/NVMe/DPTF),
  # audio codec power_save, NMI watchdog off. NixOS's services.powertop option
  # no longer exists on this nixpkgs branch, hence the manual unit.
  systemd.services.powertop = {
    description = "Powertop auto-tuning";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        "${pkgs.powertop}/bin/powertop --auto-tune"
        # Re-pin the Logitech receiver to "on" after tuning (see above).
        "${keep-mouse-awake}"
      ];
    };
  };

}
