# koru: Btrfs mount policy; UUIDs remain in hardware-configuration.nix.
{
  # btrfs: zstd compression (faster reads on NVMe), noatime (no write on every
  # read, less SSD wear) and discard=async (queued TRIM, no fstrim timer).
  fileSystems."/" = {
    options = [
      "compress=zstd"
      "noatime"
      "discard=async"
    ];
  };
  fileSystems."/home" = {
    options = [
      "compress=zstd"
      "noatime"
      "discard=async"
    ];
  };
  fileSystems."/nix" = {
    options = [
      "compress=zstd"
      "noatime"
      "discard=async"
    ];
  };
}
