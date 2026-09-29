# --- fzf ---
# Fuzzy finder. zsh integration binds Ctrl-R (history), Ctrl-T (files) and
# Alt-C (dirs); fzf-tab adds fuzzy completion menus on <Tab>. Colors and the
# default file/dir command (fd, installed in home/fd.nix) come from here.
{
  lib,
  theme,
  pkgs,
  ...
}:
let
  # fzf-tab's group labels take raw ANSI escape sequences, so build truecolor
  # SGR strings straight from the hex palette: `$'\e[38;2;R;G;Bm'`.
  hexToRgb =
    c:
    let
      d = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
      };
      s = lib.toLower (lib.removePrefix "#" c);
      byte = i: d.${builtins.substring i 1 s} * 16 + d.${builtins.substring (i + 1) 1 s};
    in
    "${toString (byte 0)};${toString (byte 2)};${toString (byte 4)}";
  fg24 = c: "$'\\e[38;2;${hexToRgb c}m'";
  # SGR params (no escape wrapper) for zsh's completion `list-colors`.
  rgb = c: "38;2;${hexToRgb c}";
  # fzf --color spec, shared by the main fzf (programs.fzf.colors below) and
  # fzf-tab. fzf-tab gets it as an explicit CLI flag because relying on it
  # inheriting FZF_DEFAULT_OPTS proved unreliable.
  # Green is used only as a sparse secondary accent (match highlight, the
  # multi-select marker and the match counter); prompt/pointer/border/spinner
  # stay orange so the layout keeps its warm identity.
  fzfColors = lib.concatStringsSep "," [
    "bg:${theme.bg}"
    "bg+:${theme.bg-alt}"
    "fg:${theme.fg}"
    "fg+:${theme.fg-bright}"
    "hl:${theme.ansi.green}"
    "hl+:${theme.ansi-bright.green}"
    "info:${theme.ansi.green}"
    "prompt:${theme.accent}"
    "pointer:${theme.accent}"
    "marker:${theme.ansi-bright.green}"
    "spinner:${theme.accent}"
    "scrollbar:${theme.accent}"
    "header:${theme.muted}"
    "border:${theme.accent}"
    "label:${theme.accent}"
    "query:${theme.fg-bright}"
    "disabled:${theme.muted-alt}"
    "gutter:${theme.bg}"
    "separator:${theme.border}"
  ];
  # Default options (non-color) and the full FZF_DEFAULT_OPTS string. The
  # string is also re-exported from .zshrc below: Home Manager's session
  # variables are guarded by __HM_SESS_VARS_SOURCED, so a shell inherited from
  # a session started before a rebuild would otherwise keep the old palette.
  fzfOpts = [
    "--height=45%"
    "--layout=reverse"
    "--border=rounded"
    "--info=inline"
    # Quote the value: an unquoted trailing space makes fzf mis-parse
    # FZF_DEFAULT_OPTS and swallow every following option (including --color).
    "--prompt='> '"
    "--pointer=▶"
    "--marker=✓"
  ];
  fzfDefaultOpts = lib.concatStringsSep " " (fzfOpts ++ [ "--color=${fzfColors}" ]);
  # Colors for the file-type entries in zsh's completion menu / fzf-tab
  # candidates. Without this they come from the stock LS_COLORS (vivid
  # blue/green), which clashes with the palette.
  listColors = [
    "di=${rgb theme.accent}"
    "ln=${rgb theme.ansi.cyan}"
    "mh=${rgb theme.muted-alt}"
    "pi=${rgb theme.ansi.yellow}"
    "so=${rgb theme.ansi.magenta}"
    "do=${rgb theme.ansi.magenta}"
    "bd=${rgb theme.ansi.yellow}"
    "cd=${rgb theme.ansi.yellow}"
    "or=${rgb theme.urgent}"
    "mi=${rgb theme.muted-alt}"
    "su=${rgb theme.ansi.red}"
    "sg=${rgb theme.ansi.red}"
    "ca=${rgb theme.ansi.red}"
    "tw=${rgb theme.ansi.cyan}"
    "ow=${rgb theme.ansi.blue}"
    "st=${rgb theme.ansi.blue}"
    "ex=${rgb theme.ansi.green}"
    "*.tar=${rgb theme.ansi.red}"
    "*.tgz=${rgb theme.ansi.red}"
    "*.gz=${rgb theme.ansi.red}"
    "*.bz2=${rgb theme.ansi.red}"
    "*.xz=${rgb theme.ansi.red}"
    "*.zip=${rgb theme.ansi.red}"
    "*.7z=${rgb theme.ansi.red}"
    "*.rar=${rgb theme.ansi.red}"
    "*.jpg=${rgb theme.ansi.magenta}"
    "*.jpeg=${rgb theme.ansi.magenta}"
    "*.png=${rgb theme.ansi.magenta}"
    "*.gif=${rgb theme.ansi.magenta}"
    "*.svg=${rgb theme.ansi.magenta}"
    "*.webp=${rgb theme.ansi.magenta}"
    "*.mp3=${rgb theme.ansi.cyan}"
    "*.flac=${rgb theme.ansi.cyan}"
    "*.wav=${rgb theme.ansi.cyan}"
    "*.mp4=${rgb theme.ansi.magenta}"
    "*.mkv=${rgb theme.ansi.magenta}"
    "*.pdf=${rgb theme.urgent}"
  ];
  # fzf-tab colors each group (and the completion description that trails the
  # candidate) with these; all the accent orange so the right-side annotation
  # matches niri's accent. fzf-tab indexes directly by group number, so provide
  # 16.
  groupColors = lib.concatStringsSep " " (lib.replicate 16 (fg24 theme.accent));
in
{
  # fzf-tab defaults to its own (unthemed) fzf palette. Pass the palette both
  # ways: inherit the global FZF_DEFAULT_OPTS *and* an explicit --color flag on
  # fzf's command line, plus recolored group labels from system/theme.nix.
  programs.zsh.initContent = lib.mkAfter ''
    zstyle ':fzf-tab:*' use-fzf-default-opts yes
    zstyle ':fzf-tab:*' fzf-flags "--color=${fzfColors}"
    zstyle ':fzf-tab:*' group-colors ${groupColors}
    zstyle ':completion:*' list-colors ${lib.concatStringsSep " " (map (c: ''"${c}"'') listColors)}

    # Re-export in every interactive shell so the fzf widgets (Ctrl-J/K/L, which
    # use FZF_DEFAULT_OPTS) always match the palette, even in shells inherited
    # from a session that predates the last rebuild.
    export FZF_DEFAULT_OPTS=${lib.escapeShellArg fzfDefaultOpts}
  '';

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = fzfOpts;
    colors = {
      bg = theme.bg;
      "bg+" = theme.bg-alt;
      fg = theme.fg;
      "fg+" = theme.fg-bright;
      hl = theme.ansi.green;
      "hl+" = theme.ansi-bright.green;
      info = theme.ansi.green;
      prompt = theme.accent;
      pointer = theme.accent;
      marker = theme.ansi-bright.green;
      spinner = theme.accent;
      scrollbar = theme.accent;
      header = theme.muted;
      border = theme.accent;
      label = theme.accent;
      query = theme.fg-bright;
      disabled = theme.muted-alt;
      gutter = theme.bg;
      separator = theme.border;
    };
    fileWidget.command = "fd --type f --hidden --follow --exclude .git";
    changeDirWidget.command = "fd --type d --hidden --follow --exclude .git";
  };

  # Sourced after compinit by HM (order 900), which is exactly what fzf-tab wants.
  # src points at the package's share/fzf-tab dir (not the default plugin path)
  # so the fzf-tab.plugin.zsh -> fzf-tab.zsh relative source resolves.
  programs.zsh.plugins = [
    {
      name = "fzf-tab";
      src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
      file = "fzf-tab.plugin.zsh";
    }
  ];
}
