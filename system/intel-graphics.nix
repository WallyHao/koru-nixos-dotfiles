# --- graphics ---
# Intel iGPU setup: the RTX 4060 dGPU is driver-less (nouveau is blacklisted
# in hosts/koru/boot.nix and no nvidia driver is installed), so display,
# render and video codec all run on the Intel iGPU with VA-API.
{ pkgs, ... }:

{
  # --- Userspace render stack ---
  # Explicit Mesa/DDX enable (already the default, kept for clarity); the i915
  # kernel driver works out of the box.
  hardware.graphics.enable = true;

  # Intel iHD VA-API driver: hardware h264/hevc/av1 decode/encode on the iGPU.
  # Without it browsers and video apps fall back to CPU decode.
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  # --- Kernel ---
  # Explicitly load GuC + HuC firmware (modern kernels default to GuC only;
  # HuC is used by media workloads / VA-API).
  boot.kernelParams = [ "i915.enable_guc=3" ];
}
