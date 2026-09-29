# Explicit system module inventory. theme.nix is data, passed via specialArgs.
{
  imports = [
    ./bluetooth-disabled.nix
    ./console.nix
    ./display-power.nix
    ./fcitx5-rime.nix
    ./firewall.nix
    ./fonts.nix
    ./github-hosts.nix
    ./gpu-screen-recorder.nix
    ./intel-graphics.nix
    ./journal-limits.nix
    ./memory-zram.nix
    ./mihomo.nix
    ./network-manager.nix
    ./niri-session.nix
    ./nix-daemon.nix
    ./nix-garbage-collection.nix
    ./openssh-server.nix
    ./pipewire-audio.nix
    ./power-management.nix
    ./tcp-tuning.nix
    ./time-servers.nix
    ./zsh-login-shell.nix
  ];
}
