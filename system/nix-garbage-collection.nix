# Scheduled Nix garbage collection and manual upgrade policy.
{
  # Daily GC via the built-in timer: drop generations older than a week, then
  # collect unreferenced store paths. Boot entries are capped independently by
  # boot.loader.systemd-boot.configurationLimit.
  nix.gc = {
    automatic = true;
    dates = "03:15";
    persistent = true;
    options = "--delete-older-than 7d";
  };
  # Auto-upgrade stays off; flake.lock and github-hosts are refreshed manually
  # with `nix flake update`, followed by an explicit rebuild. `dates`/`flake` are not
  # set: they are inert while `enable` is false.
  system.autoUpgrade.enable = false;
}
