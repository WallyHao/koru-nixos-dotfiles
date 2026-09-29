# koru: systemd-boot, initrd, kernel parameters and driver exclusions.
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;
  # Tiny 256M ESP: keep only the 5 newest generations (each initrd is ~44M) or
  # rebuilds fail with "No space left on device".
  boot.loader.systemd-boot.configurationLimit = 5;

  # --- Kernel ---
  # Quiet boot: less console spam. nowatchdog disables the kernel lockup
  # watchdog timers (NMI/scheduler), saving a bit of boot and idle CPU time.
  boot.kernelParams = [
    "quiet"
    "8250.nr_uarts=0"
    "nowatchdog"
    "nmi_watchdog=0"
  ];

  # No LUKS/cryptenroll/PCR usage, so drop TPM probing from the initrd: the
  # tpm2.target wait on the (slow) Intel iTPM was adding ~1-3s to boot.
  boot.initrd.systemd.tpm2.enable = false;

  # Driver blacklist:
  # - tpm_crb/tpm_tis: the Intel iTPM (INTC6001, tpm_crb) takes ~3s to respond
  #   during udev coldplug, blocking the whole device queue (even NVMe gets
  #   delayed). No TPM usage at all, so stop probing it in initrd + userspace.
  # - iTCO_wdt: Intel TCO hardware watchdog: can't be stopped at power-off, so
  #   the kernel prints "watchdog did not stop!" every shutdown. Unused anyway.
  # - nouveau: drives the unused RTX 4060 dGPU (display runs on the Intel
  #   iGPU). nouveau must talk to the GSP firmware on this chip, which fails
  #   every boot and spams ~33 identical "gsp ... ctrl cmd failed" errors.
  # - xe: the new Intel GPU driver also matches the Raptor Lake-S iGPU
  #   (8086:a78b) but refuses to drive it ("not officially supported"). It can
  #   win the PCI modalias race against i915: xe then declines the device and
  #   i915 never binds, leaving only simpledrm, so niri starts with no render
  #   node and the screen stays black at the tty1 autologin. Force i915.
  boot.blacklistedKernelModules = [
    "tpm_crb"
    "tpm_tis"
    "iTCO_wdt"
    "nouveau"
    "xe"
  ];

  # systemd-initrd: parallel device probing, faster and more robust.
  boot.initrd.systemd.enable = true;
  # Load crc32c before btrfs mounts /sysroot: without it btrfs fails with
  # "error allocating crc32c hash for checksum" (systemd-initrd module order).
  boot.initrd.kernelModules = [
    "crc32c_cryptoapi"
    "autofs4"
  ];
  # availableKernelModules is intentionally left to hardware-configuration.nix:
  # overriding it (even to "trim" modules) silently drops whatever the generated
  # list gains on a kernel or hardware change.
}
