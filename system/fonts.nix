# --- fonts ---
# Fonts. Maple Mono NF-CN is the global theme font and stays the monospace
# default. sans-serif / serif are proper proportional families instead of being
# aliased to the mono font, so UI text (GTK, browser) reads comfortably.
#
# NOTE: a few apps with their own text renderers (e.g. Electron/Chromium-style
# stacks) ignore the fontconfig hinting/subpixel settings below; they still
# sharpen Kitty, GTK and most native toolkits.
{ pkgs, theme, ... }:

let
  # SourceForge downloads can fail with HTTP 522. Use byte-identical archives
  # with the hashes from nixpkgs/corefonts, retaining SourceForge as a fallback.
  fetchCoreFont =
    name: hash:
    pkgs.fetchurl {
      urls = [
        "https://archive.netbsd.org/pub/pkgsrc-archive/distfiles/2017Q3/ms-ttf/${name}32.exe"
        "https://raw.githubusercontent.com/amontalban/mscorefonts/319ad34db8d5faec615df6807dfaa9d911cdc4e1/${name}32.exe"
        "mirror://sourceforge/corefonts/the%20fonts/final/${name}32.exe"
      ];
      inherit hash;
      curlOpts = "--connect-timeout 10 --max-time 45";
    };

  # The paper needs Arial and Times New Roman. The original Webdings archive
  # supplies the bundled core-fonts EULA; its font is not installed.
  paperCorefonts = pkgs.corefonts.overrideAttrs (previous: {
    pname = "corefonts-paper";
    env = previous.env // {
      exes = toString [
        (fetchCoreFont "arial" "sha256-hSl6TRRunIesb3SCJzS97l9LKnItfqpYS38sv3b0ePY=")
        (fetchCoreFont "times" "sha256-21ZZXsbvXT3lwkmU8AHwOyoT43zuJ7wlxY9vQ+j4B6s=")
      ];
    };
    nativeBuildInputs = [ pkgs.cabextract ];
    buildCommand = ''
      for archive in $exes; do
        cabextract --lowercase "$archive"
      done
      install -m444 -Dt "$out/share/fonts/truetype" *.ttf

      cabextract --lowercase --filter 'Licen.TXT' ${fetchCoreFont "webdin" "sha256-ZFlbWrwQgPuoYQxcNPq1hjQI6Aaq/oRlPKhXW+0X11o="}
      install -m444 -Dt "$out/share/doc/corefonts" licen.txt
    '';
    meta = previous.meta // {
      description = "Microsoft Arial and Times New Roman fonts with bundled EULA";
    };
  });
in
{
  fonts.packages = with pkgs; [
    maple-mono.NF-CN
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif

    # Academic typesetting: original CM/AMS designs with optical sizes, plus
    # Unicode text fonts and OpenType math fonts usable by Typst. CM-Super's
    # Type 1 fonts cannot be used directly by Typst.
    bakoma_ttf
    cm_unicode
    newcomputermodern

    # Arial for plot labels; Times New Roman is a substitute for PDF Times-Roman.
    paperCorefonts
  ];

  fonts.fontconfig = {
    antialias = true;
    hinting = {
      enable = true;
      style = "slight";
    };
    # RGB subpixel rendering. If text shows colour fringing, switch to "bgr".
    subpixel = {
      rgba = "rgb";
      lcdfilter = "default";
    };
    defaultFonts = {
      monospace = [ theme.font ];
      sansSerif = [
        "Noto Sans"
        "Noto Sans CJK SC"
      ];
      serif = [
        "Noto Serif"
        "Noto Serif CJK SC"
      ];
    };
  };
}
