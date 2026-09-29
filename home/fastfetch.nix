# --- fastfetch ---
# On-demand system info. No ASCII logo (logo.type = "none"), and the module
# list adds Sound + Brightness to the usual host/kernel/CPU/GPU/memory/disk.
_: {
  programs.fastfetch = {
    enable = true;
    settings = {
      logo.type = "none";
      display.separator = "  ";
      modules = [
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "wm"
        "cpu"
        "gpu"
        "memory"
        "disk"
        "localip"
        "battery"
        "sound"
        "brightness"
        "colors"
      ];
    };
  };
}
