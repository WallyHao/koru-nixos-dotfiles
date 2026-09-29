# koru host composition. Hardware identities and state version are preserved.
{ hostname, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./btrfs-mounts.nix
    ./locale.nix
    ./user-account.nix
  ];
  networking.hostName = hostname;
  system.stateVersion = "26.11";
}
