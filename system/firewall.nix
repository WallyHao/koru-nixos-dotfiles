# Application-specific inbound firewall ports (SSH is in openssh-server.nix).
{
  # Allow LAN devices to reach koru file and local static/Slidev servers on 8080.
  networking.firewall.allowedTCPPorts = [ 8080 ];
}
