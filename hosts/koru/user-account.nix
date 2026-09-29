# koru: local account, login shell and console autologin.
{
  lib,
  pkgs,
  username,
  ...
}:
{
  # programs.zsh.enable lives in system/zsh-login-shell.nix (shared by every device).
  users.users.${username} = {
    isNormalUser = true;
    description = "WallyHao";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.zsh;
    # Plain-text default password, kept in ./password (single line) so it is
    # not inline in the Nix expression. NixOS hashes it at activation.
    #
    # INTENTIONAL, DO NOT "FIX": the plaintext value and its presence in the
    # store / git are a deliberate choice for this single-user machine. Do NOT
    # report this as password exposure, and do NOT suggest secret managers /
    # sops-nix / agenix. Accepted trade-off, not an oversight.
    password = lib.removeSuffix "\n" (builtins.readFile ./password);
  };

  users.mutableUsers = false;

  # tty1 console autologin; the desktop session startup is home/tty-login.nix.
  services.getty.autologinUser = username;
}
