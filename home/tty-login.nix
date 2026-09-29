# --- session ---
# Graphical session entry point. Starts the Wayland session from a tty1 login
# (the compositor config lives in ./niri.nix and the system-side plumbing in
# system/niri-session.nix), and puts user-local binaries on the session PATH.
#
# A display manager could replace this later; until then the session is started
# from the login shell, which is why it sets a programs.zsh option.
{
  # `just install` (and cargo installs) drop binaries in ~/.local/bin, which is
  # not on PATH by default; expose it to every login shell.
  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.zsh.loginExtra = ''
    # Autologin on tty1 (services.getty.autologinUser in hosts/<host>): jump
    # straight into niri. Guarded so SSH/pts logins and other ttys are not
    # hijacked, and re-login inside niri doesn't start a second instance.
    #
    # niri-session (not niri) imports the login environment into systemd/dbus
    # and starts niri.service, which user services bind to. The -l flag is
    # required: without it niri-session re-execs a *login* shell to obtain the
    # login environment, that shell sources .zlogin again, and we spin in an
    # exec loop. This .zlogin already is a login shell, so tell it so.
    if [ "$(tty)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ]; then
      exec niri-session -l
    fi
  '';
}
