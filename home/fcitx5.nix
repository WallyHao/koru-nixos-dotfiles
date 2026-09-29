# --- fcitx5 ---
# Input method user config: custom "warm-apricot" theme (generated from the
# global theme), Rime (rime-ice) input method, Maple Mono font.
{ pkgs, theme, ... }:
let
  # SVG accepts #RRGGBBAA; theme colors carry no alpha, so append the two hex
  # digits here to keep system/theme.nix the single source of truth.
  withAlpha = c: a: "${c}${a}";

  # Panel: rounded dark background with a fg->accent->red gradient border.
  panel-svg = pkgs.writeText "panel.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80">
      <defs>
        <linearGradient id="b" x1="1" y1="1" x2="0" y2="0">
          <stop offset="0%" stop-color="${theme.fg}"/>
          <stop offset="50%" stop-color="${theme.accent}"/>
          <stop offset="100%" stop-color="${theme.ansi.red}"/>
        </linearGradient>
      </defs>
      <rect x="3" y="3" width="74" height="74" rx="12" ry="12" fill="${withAlpha theme.bg "EB"}"/>
      <rect x="3" y="3" width="74" height="74" rx="12" ry="12" fill="none" stroke="url(#b)" stroke-width="2"/>
    </svg>
  '';

  # Highlight: translucent urgent-orange rounded block.
  highlight-svg = pkgs.writeText "highlight.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80">
      <rect x="3" y="11" width="74" height="58" rx="12" ry="12" fill="${withAlpha theme.urgent "E0"}"/>
      <rect x="3" y="11" width="74" height="58" rx="12" ry="12" fill="none" stroke="${withAlpha theme.accent-bright "40"}" stroke-width="1.5"/>
    </svg>
  '';

  # Render the SVGs to PNG once at build time.
  panel-png = pkgs.runCommand "panel.png" {
    buildInputs = [ pkgs.librsvg ];
  } "rsvg-convert -w 80 -h 80 ${panel-svg} -o $out";

  highlight-png = pkgs.runCommand "highlight.png" {
    buildInputs = [ pkgs.librsvg ];
  } "rsvg-convert -w 80 -h 80 ${highlight-svg} -o $out";
in
{
  xdg.configFile."fcitx5/profile".text = ''
    [Groups/0]
    # Group Name
    Name=Default
    # Layout
    Default Layout=us
    # Default Input Method
    DefaultIM=rime

    [Groups/0/Items/0]
    # Name
    Name=keyboard-us
    # Layout
    Layout=

    [Groups/0/Items/1]
    # Name
    Name=rime
    # Layout
    Layout=

    [GroupOrder]
    0=Default
  '';

  # Rime only needs the user layer: the scheme ships in the system-side
  # fcitx5-rime wrapper (rime-ice), so this activates it and keeps the
  # 7-candidate page the old pinyin engine used.
  xdg.dataFile."fcitx5/rime/default.custom.yaml".text = ''
    patch:
      __include: rime_ice_suggestion:/
      menu/page_size: 7
  '';

  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Theme=custom
    Font=${theme.font} ${toString theme.font-size}
    Vertical Candidate List=False
  '';

  # Theme files (fonts/colors follow the global theme).
  xdg.dataFile."fcitx5/themes/custom/theme.conf".text = ''
    [Metadata]
    Name=Custom Dark
    Version=1
    Author=wallyhao
    Description=Dark rounded theme with gradient border and transparency

    [InputPanel]
    NormalColor=${theme.fg}
    HighlightCandidateColor=${theme.accent}
    HighlightColor=${theme.accent}
    HighlightBackgroundColor=#00000000
    FullWidthHighlight=True

    [InputPanel/Background]
    Image=panel.png
    Color=#00000000
    BorderColor=#ffffff00
    BorderWidth=0

    [InputPanel/Background/Margin]
    Left=18
    Right=18
    Top=18
    Bottom=18

    [InputPanel/Highlight]
    Image=
    Color=#00000000
    BorderColor=#ffffff00
    BorderWidth=0

    [InputPanel/Highlight/Margin]
    Left=8
    Right=8
    Top=6
    Bottom=6

    [InputPanel/ContentMargin]
    Left=8
    Right=8
    Top=6
    Bottom=6

    [InputPanel/TextMargin]
    Left=6
    Right=6
    Top=4
    Bottom=4

    [InputPanel/PrevPage]
    Image=

    [InputPanel/NextPage]
    Image=

    [InputPanel/ShadowMargin]
    Left=0
    Right=0
    Top=0
    Bottom=0
  '';

  xdg.dataFile."fcitx5/themes/custom/panel.png" = {
    source = panel-png;
  };
  xdg.dataFile."fcitx5/themes/custom/highlight.png" = {
    source = highlight-png;
  };
}
