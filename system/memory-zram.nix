# Compressed swap, VM reclaim and user-slice memory-pressure handling.
{ config, ... }:
{
  assertions = [
    {
      assertion = config.swapDevices == [ ];
      message = "memory-zram.nix uses vm.swappiness=180 for RAM-backed swap; review the policy before adding disk swap.";
    }
  ];
  # systemd-oomd: kill the biggest *user* process under memory pressure instead
  # of letting the kernel OOM killer freeze the whole desktop. Pairs with zram
  # (configured below).
  systemd.oomd.enable = true;
  systemd.oomd.enableUserSlices = true;

  # --- zram in-memory swap ---
  # Only valid because ALL swap is in-memory on this machine (no disk swap:
  # swapDevices = []); if a swapfile is ever added, revert vm.swappiness to
  # <=60 or cold pages will thrash onto disk.
  #
  # 8G zram (34% of 23G RAM), compressed in memory: no SSD wear, and gives the
  # OOM killer room to breathe before the system freezes.
  zramSwap = {
    enable = true;
    memoryPercent = 34;
    # zstd beats lz4 on compress ratio with negligible CPU cost here.
    algorithm = "zstd";
  };

  boot.kernel.sysctl = {
    # Prefer swapping to zram (range 0-200, default 60): compressed pages and
    # their reclaim are cheap.
    "vm.swappiness" = 180;
    # Disable watermark boost: let RAM fill up before the kernel reclaims.
    "vm.watermark_boost_factor" = 0;
    # Wake kswapd earlier (free memory below 1/125 of RAM) so allocation
    # pressure stays smooth instead of sudden swap storms at high swappiness.
    "vm.watermark_scale_factor" = 125;
    # zram is memory-adjacent: swap readahead just fetches useless pages.
    "vm.page-cluster" = 0;
  };
}
