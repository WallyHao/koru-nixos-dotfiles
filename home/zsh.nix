# --- zsh ---
# oh-my-zsh + powerlevel10k + autosuggestions + syntax-highlighting.
# p10k.zsh is the interactive `p10k configure` output (256-color indexed,
# versioned as-is) and is regenerated there rather than hand-maintained.
#
# p10k colors are NOT hardcoded in p10k.zsh: after the wizard config is sourced
# the palette below overrides it from system/theme.nix, so re-running `p10k configure`
# can't break the theme.
{
  config,
  lib,
  pkgs,
  theme,
  enabled,
  ...
}:
let
  # Koru Fern palette pulled from the global theme (system/theme.nix).
  palette = {
    bg = theme.bg;
    panel = theme.bg-alt;
    fg = theme.fg;
    bright = theme.fg-bright;
    black = theme.black;
    accent = theme.accent;
    accentDeep = theme.accent-deep;
    accentBright = theme.accent-bright;
    sel = theme.accent-bg;
    muted = theme.muted;
    dim = theme.muted-alt;
    urgent = theme.urgent;
    border = theme.border;
    red = theme.ansi.red;
    green = theme.ansi.green;
    yellow = theme.ansi.yellow;
    blue = theme.ansi.blue;
    magenta = theme.ansi.magenta;
    cyan = theme.ansi.cyan;
    white = theme.ansi.white;
  };

  # Pure-style p10k (home/dotfiles/p10k.zsh) draws text-only on a transparent
  # background, so only *_FOREGROUND colors matter; setting *_BACKGROUND would
  # reintroduce colored blocks and defeat the style. Applied after the wizard
  # config is sourced, so the wizard's own colors never win.
  p10kColors = {
    # Prompt symbol: accent on success, urgent on error.
    PROMPT_CHAR_OK_VIINS_FOREGROUND = palette.accentBright;
    PROMPT_CHAR_OK_VICMD_FOREGROUND = palette.accentBright;
    PROMPT_CHAR_OK_VIVIS_FOREGROUND = palette.accentBright;
    PROMPT_CHAR_ERROR_VIINS_FOREGROUND = palette.urgent;
    PROMPT_CHAR_ERROR_VICMD_FOREGROUND = palette.urgent;
    PROMPT_CHAR_ERROR_VIVIS_FOREGROUND = palette.urgent;

    # Segments.
    # Path layering: base path in neutral text color, "/" separators in dim
    # muted-alt so the hierarchy reads clearly, last segment in accent as the
    # "you are here" focus (bold). Pure-style shows the full path.
    DIR_FOREGROUND = palette.fg;
    DIR_PATH_SEPARATOR_FOREGROUND = palette.dim;
    DIR_PATH_HIGHLIGHT_FOREGROUND = palette.accent;
    DIR_PATH_HIGHLIGHT_BOLD = "true";
    VCS_FOREGROUND = palette.green;
    VCS_INCOMING_CHANGESFORMAT_FOREGROUND = palette.cyan;
    VCS_OUTGOING_CHANGESFORMAT_FOREGROUND = palette.cyan;
    TIME_FOREGROUND = palette.muted;
    VIRTUALENV_FOREGROUND = palette.cyan;
    COMMAND_EXECUTION_TIME_FOREGROUND = palette.yellow;
    CONTEXT_FOREGROUND = palette.muted;

    # The pure config hardcodes colors inside the context templates, so theme
    # those directly as well.
    CONTEXT_ROOT_TEMPLATE = "%F{${palette.bright}}%n%f%F{${palette.muted}}@%m%f";
    CONTEXT_TEMPLATE = "%F{${palette.muted}}%n@%m%f";
  };

  p10kOverrideLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (k: v: "typeset -g POWERLEVEL9K_${k}='${v}'") p10kColors
  );
in
{
  home.packages = [
    pkgs.zsh-powerlevel10k
    # The `home-manager` CLI is provided by home/default.nix, which adds
    # pkgs.home-manager when embedded and relies on programs.home-manager.enable
    # when standalone. Adding it here too would duplicate bin/home-manager.
  ];

  # p10k state: created with `p10k configure`, versioned here.
  home.file.".p10k.zsh" = {
    source = ./dotfiles/p10k.zsh;
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # compinit's security audit (compaudit) walks every fpath entry; on NixOS
    # they are all root-owned read-only /nix/store paths, so the scan is pure
    # startup overhead. -u (this flag) skips the ownership fixups.
    sessionVariables.ZSH_DISABLE_COMPFIX = "true";

    "oh-my-zsh" = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "colored-man-pages"
        "extract" # `x <archive>` unpacks anything
        "copyfile" # `copyfile <f>` -> clipboard (wl-copy via WAYLAND_DISPLAY)
        "copypath" # `copypath` -> clipboard
        # "z" is intentionally absent: zoxide (home/zoxide.nix) replaces it.
      ];
      # Activate the p10k prompt itself. Sourcing ~/.p10k.zsh only sets
      # POWERLEVEL9K_* variables; the theme must be loaded for them to matter.
      # The package lays out share/zsh/themes/powerlevel10k/, so ZSH_CUSTOM
      # must be .../share/zsh and the theme name needs the powerlevel10k/ prefix.
      theme = "powerlevel10k/powerlevel10k";
      custom = "${pkgs.zsh-powerlevel10k}/share/zsh";
    };
    shellAliases = {
      nixos-system-rebuild = "nosr";
      nixos-homemanager-update = "nohm";
    }
    // lib.optionalAttrs (enabled.enable.bat or false) {
      cat = "bat";
      catp = "bat -pp";
    }
    // lib.optionalAttrs (enabled.enable.eza or false) {
      l = "eza --tree --group-directories-first -L 1";
      ls = "eza --tree --group-directories-first --long -L 1";
      la = "eza -la --tree --group-directories-first -L 1";
    }
    // lib.optionalAttrs (enabled.enable.fastfetch or false) {
      fetch = "fastfetch";
    };

    # Quality-of-life shell options (applied after oh-my-zsh, so they win).
    setOptions = [
      "AUTO_CD" # typing a directory name enters it
      "AUTO_PUSHD" # cd pushes onto the dir stack
      "PUSHD_IGNORE_DUPS"
      "PUSHD_SILENT"
      "SHARE_HISTORY" # all shells read/append the same history
      "HIST_IGNORE_ALL_DUPS"
      "HIST_IGNORE_SPACE" # commands starting with a space stay out of history
      "HIST_REDUCE_BLANKS"
      "HIST_VERIFY"
      "INTERACTIVE_COMMENTS"
    ];

    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        # Profile completions follow its installed generation, including rollback.
        # Register before compinit/Oh My Zsh; no package installation is owned here.
        fpath=("''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/koru-dev/share/zsh/site-functions" $fpath)
      '')
      (lib.mkAfter ''
        # API keys / secrets (chmod 600, not tracked by git). Sourced here, in
        # .zshrc, which runs before .zlogin's `exec niri-session`; niri and every
        # child (opencode, ...) inherit the exported vars.
        [ -r "$HOME/.config/zsh/secrets.env" ] && source "$HOME/.config/zsh/secrets.env"

        # Large, shared history (SHARE_HISTORY is set via setOptions above).
        HISTSIZE=100000
        SAVEHIST=100000

        ${lib.optionalString (enabled.enable.bat or false) ''
          # Use bat as the man-page pager (col strips overstrike/backspaces).
          export MANPAGER="sh -c '${pkgs.util-linux}/bin/col -bx | ${pkgs.bat}/bin/bat -l man -p'"
          export MANROFFOPT="-c"
        ''}

        # powerlevel10k (sourced after oh-my-zsh sets the theme)
        source ${config.home.homeDirectory}/.p10k.zsh

        # Re-theme p10k to the global Koru Fern palette (system/theme.nix). Set after
        # the wizard config so these win, then force p10k to re-init.
        ${p10kOverrideLines}
        (( ! $+functions[p10k] )) || p10k reload

        # Rebuild helpers: optional host (default koru).
        nosr() { "$HOME/.config/nixos/scripts/maintenance.sh" system-configuration switch "''${1:-koru}"; }
        nohm() { "$HOME/.config/nixos/scripts/maintenance.sh" home-configuration switch "''${1:-koru}"; }

        ${lib.optionalString (enabled.enable.libreoffice or false) ''
          # Convert a doc/ppt (docx/pptx/odt/odp/...) to PDF with headless
          # LibreOffice (installed by home/libreoffice.nix).
          #   topdf <input> <target>
          # <target> is either an existing directory (or a path ending in "/"),
          # where the PDF keeps the input's basename, or a full output path that
          # renames it. LibreOffice always names the result after the input, so
          # convert into a private temp dir and move the file to the target; the
          # private profile also avoids clashing with a running LibreOffice.
          topdf() {
            if [ "$#" -ne 2 ]; then
              echo "usage: topdf <input> <target-dir-or-pdf-path>" >&2
              return 2
            fi
            local input="$1" target="$2" outdir outname tmp stem
            [ -f "$input" ] || { echo "topdf: no such file: $input" >&2; return 1; }
            input="$(realpath "$input")"
            stem="$(basename "$input")"; stem="''${stem%.*}"
            if [ -d "$target" ] || [ "''${target%/}" != "$target" ]; then
              outdir="$target"; outname="$stem.pdf"
            else
              outdir="$(dirname "$target")"; outname="$(basename "$target")"
            fi
            mkdir -p "$outdir"
            tmp="$(mktemp -d)" || return 1
            soffice --headless \
              "-env:UserInstallation=file://$tmp/profile" \
              --convert-to pdf --outdir "$tmp" "$input" >/dev/null
            if [ -f "$tmp/$stem.pdf" ]; then
              mv -f "$tmp/$stem.pdf" "$outdir/$outname"
              echo "$outdir/$outname"
            else
              echo "topdf: conversion failed: $input" >&2
              rm -rf "$tmp"
              return 1
            fi
            rm -rf "$tmp"
          }
        ''}

        ${lib.optionalString (enabled.enable.zen-browser or false) ''
          # Open a file/folder in Zen (the browser installed by home/zen-browser.nix, binary
          # zen-beta) in a NEW window (never a new tab). Kept in sync with the
          # Alt+l bind in home/niri.nix, which also spawns zen-beta.
          # Usage: f [file-or-path]  (defaults to the current directory)
          f() {
            if [ -z "$1" ]; then
              zen-beta --new-window "file://$PWD"
            else
              case "$1" in
                /*) local url="file://$1" ;;
                *)  local url="file://$PWD/$1" ;;
              esac
              zen-beta --new-window "$url"
            fi
          }
        ''}

        ${lib.optionalString (enabled.enable.eza or false) ''
          # eza tree helpers that take an optional depth as the first argument:
          #   ll [depth] [path]   detailed tree, default depth 1
          #   lt [depth] [path]   compact tree,  default depth 5
          unalias ll lt 2>/dev/null
          ll() {
            local d=1
            if [[ "$1" == <-> ]]; then d="$1"; shift; fi
            eza --tree --group-directories-first --long -L "$d" "$@"
          }
          lt() {
            local d=5
            if [[ "$1" == <-> ]]; then d="$1"; shift; fi
            eza --tree --group-directories-first -L "$d" "$@"
          }
        ''}

        ${lib.optionalString (enabled.enable.fzf or false) ''
          # fzf widgets on three consecutive home-row keys, under Win (Super).
          # Super does not reach the shell on its own, so Kitty converts Win+J/K/L
          # into ESC j/k/l (Meta) - see home/kitty.nix.
          # Ctrl+J/K/L are restored to their zsh defaults.
          #   Win+J history, Win+K files, Win+L dirs
          bindkey -r '^R';  bindkey '^R'  history-incremental-search-backward
          bindkey -r '^T';  bindkey '^T'  transpose-chars
          bindkey -r '^[c'; bindkey '^[c' capitalize-word
          bindkey '^J' accept-line
          bindkey '^K' kill-line
          bindkey '^L' clear-screen
          bindkey '^[j' fzf-history-widget
          bindkey '^[k' fzf-file-widget
          bindkey '^[l' fzf-cd-widget

          # fzf's own zsh integration (sourced earlier as `fzf --zsh`) also claims
          # Tab for its `fzf-completion` widget, shadowing the fzf-tab plugin that
          # Home Manager loaded above. Hand Tab back to fzf-tab.
          bindkey '^I' fzf-tab-complete
        ''}

      '')
    ];
  };
}
