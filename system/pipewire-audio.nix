# --- audio ---
# Audio: PipeWire with ALSA/Pulse bridging (modern Wayland stack).
#
# System layer: the NixOS module configures the audio stack once for the whole
# machine, so it is not tied to a per-user profile. A TTY-only install could
# drop it, but this host always runs a graphical session.
_: {
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
