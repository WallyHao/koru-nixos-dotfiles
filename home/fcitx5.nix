# --- fcitx5 ---
# Input method user config: custom Koru Fern theme (generated from the
# global theme), Rime (rime-ice) input method, Maple Mono font.
{ pkgs, theme, ... }:
let
  # Panel: dark surface with a subdued fern border. Warning colors remain
  # reserved for actual warnings rather than decorative chrome.
  panel-svg = pkgs.writeText "panel.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80">
      <rect x="3" y="3" width="74" height="74" rx="12" ry="12" fill="${theme.bg}"/>
      <rect x="3" y="3" width="74" height="74" rx="12" ry="12" fill="none" stroke="${theme.accent-yellow}" stroke-width="2"/>
    </svg>
  '';

  # Render the SVG to PNG once at build time.
  panel-png = pkgs.runCommand "panel.png" {
    buildInputs = [ pkgs.librsvg ];
  } "rsvg-convert -w 80 -h 80 ${panel-svg} -o $out";
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
      ascii_composer/switch_key/Shift_L: commit_code
      ascii_composer/switch_key/Shift_R: commit_code
  '';

  # Framework-level input-method switching (normally Ctrl+Space) commits the
  # raw Latin composition instead of the previewed Chinese candidate.
  xdg.configFile."fcitx5/conf/rime.conf".text = ''
    SwitchInputMethodBehavior=CommitRawInput
  '';

  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Theme=custom
    Font=${theme.font} ${toString theme.font-size}
    Vertical Candidate List=False
  '';

  # Theme files (fonts/colors follow the global theme).
  xdg.dataFile."fcitx5/themes/custom/theme.conf".text = ''
    [Metadata]
    Name=Koru Fern
    Version=1
    Author=koru
    Description=Dark fern theme with a subdued border

    [InputPanel]
    NormalColor=${theme.fg}
    # Keep the selected candidate readable through text color only; the
    # transparent highlight removes the selection box/background.
    HighlightCandidateColor=${theme.accent-yellow}
    HighlightColor=${theme.accent-yellow}
    HighlightBackgroundColor=#00000000
    FullWidthHighlight=False

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
}
