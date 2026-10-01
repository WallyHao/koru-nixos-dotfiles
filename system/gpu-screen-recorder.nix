# --- screencast ---
# Screen recording with gpu-screen-recorder (NVIDIA-free: uses the Intel
# iGPU's VA-API encoder via gsr-kms-server). intel-media-driver lives in
# hosts/koru/intel-graphics.nix.
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.gpu-screen-recorder ];

  # gsr-kms-server needs cap_sys_admin to control the KMS server for screen
  # recording; without it gpu-screen-recorder falls back to pkexec, which fails
  # on NixOS ("pkexec must be setuid root"), so recording dies with exit code 127.
  security.wrappers.gsr-kms-server = {
    setuid = false;
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+ep";
    source = "${pkgs.gpu-screen-recorder}/bin/gsr-kms-server";
  };
}
