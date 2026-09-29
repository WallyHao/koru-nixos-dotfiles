# NetworkManager and Wi-Fi power-saving policy.
{
  networking.networkmanager.enable = true;

  # Wi-Fi power saving: on battery the NIC rests between packets
  # (~0.2-0.4W); latency impact is negligible with modern iwlwifi runtime PM.
  networking.networkmanager.settings."connection"."wifi.powersave" = 3;

  systemd.services.NetworkManager-wait-online.enable = false;
  # Mainland-friendly public DNS with IPv6 entries.
  networking.nameservers = [
    "119.29.29.29" # DNSPod
    "223.5.5.5" # AliDNS
    "2402:4e00::" # DNSPod IPv6
    "2400:3200::1" # AliDNS IPv6
  ];
}
