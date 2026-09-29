# Application-specific inbound firewall ports (SSH is in openssh-server.nix).
{
  # Allow LAN devices to reach the local static/Slidev server on 8080.
  networking.firewall.allowedTCPPorts = [ 8080 ];
}
