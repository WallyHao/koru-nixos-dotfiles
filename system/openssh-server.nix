# --- ssh ---
# OpenSSH server: password login on the default port 22, reachable from any
# network. /etc/ssh host keys are generated on first boot, so no key material
# is stored in the repo.
{
  services.openssh = {
    enable = true;

    settings = {
      # Password login keeps external clients (no authorised keys on this
      # machine yet) able to connect; switch to key-only once a key exists.
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";

      # PerSourcePenalties (default on since OpenSSH 9.8) bans a source IP for
      # up to 10 minutes after a few mistyped usernames or passwords. That
      # locked out legitimate LAN clients on this shared /14, so it is disabled;
      # this is an accepted trade-off while password login stays enabled.
      PerSourcePenalties = "no";
    };

    # Opens TCP 22 in the firewall, keeping the SSH rules next to the service
    # instead of duplicating them in system/network-manager.nix.
    openFirewall = true;
  };
}
