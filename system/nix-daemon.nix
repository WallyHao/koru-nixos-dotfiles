# --- nix ---
# Nix daemon settings: substituters, parallelism and automatic store GC
# thresholds. Split out of the host file so the host only holds device identity
# (boot/fs/user) and this stays reusable platform tuning.
_: {
  # Single-user machine: allow unfree (e.g. firmware) everywhere. Kept here
  # rather than in the host file so every device shares the choice.
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # BFSU first: chsrc speed-tested it fastest on this connection (31 MB/s
    # vs USTC's 2.9 MB/s); the rest are fallbacks so a slow mirror can't stall.
    substituters = [
      "https://mirrors.bfsu.edu.cn/nix-channels/store"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
      # ROS 2 binaries (profile/packages/ros2.nix) live only here; without it the
      # whole ROS closure would build from source. May be slow from CN.
      "https://ros.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo="
    ];
    # Let wheel users (wallyhao) use their chsrc-set ~/.config/nix/nix.conf
    # without the "ignoring untrusted substituter" warning.
    trusted-users = [
      "root"
      "@wheel"
    ];
    fallback = true;
    connect-timeout = 10;
    download-attempts = 3;
    # More parallel downloads and on-the-fly store dedup (hardlinks) instead
    # of waiting for a scheduled optimise.
    max-substitution-jobs = 32;
    # 20 threads x full parallel gcc easily OOMs (QtWebEngine link peaks at
    # ~10GB); cap at 4 concurrent builds x 8 cores to stay under 23G RAM.
    max-jobs = 4;
    cores = 8;
    # Daemon auto-GC: whenever free disk drops below 5G, collect until 10G.
    # Complements the nightly timer below.
    min-free = "${toString (5 * 1024 * 1024 * 1024)}";
    max-free = "${toString (10 * 1024 * 1024 * 1024)}";
    auto-optimise-store = true;
  };
}
