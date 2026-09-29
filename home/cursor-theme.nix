# --- cursor ---
# Bibata Modern cursor recolored to the global theme: fill becomes theme.black,
# the white border becomes theme.accent. Built inline here (a single package,
# so no separate pkgs/ layer) and installed through home.pointerCursor, which
# replaces the old system-wide installation.
{ pkgs, theme, ... }:

let
  koruCursor = pkgs.stdenvNoCC.mkDerivation {
    pname = "bibata-cursors-koru";
    version = "2.0.7";

    src = pkgs.fetchFromGitHub {
      owner = "ful1e5";
      repo = "Bibata_Cursor";
      rev = "v2.0.7";
      hash = "sha256-kIKidw1vditpuxO1gVuZeUPdWBzkiksO/q2R/+DUdEc=";
    };

    bitmaps = pkgs.fetchzip {
      url = "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/bitmaps.zip";
      hash = "sha256-4VjyNWry0NPnt5+s0od/p18gry2O0ZrknYZh+PAPM8Q=";
    };

    nativeBuildInputs = [
      pkgs.clickgen
      pkgs.imagemagick
    ];

    buildPhase = ''
      runHook preBuild

      # Recolor the amber bitmaps: fill to theme.black, border to theme.accent.
      mkdir -p $PWD/bitmaps
      cp -r $bitmaps/Bibata-Modern-Amber $PWD/bitmaps/Bibata-Modern-Koru
      chmod -R u+w $PWD/bitmaps/Bibata-Modern-Koru
      find $PWD/bitmaps/Bibata-Modern-Koru -name '*.png' -exec convert {} -fuzz 15% -fill '${theme.black}' -opaque '#FF8300' -type TrueColorMatte PNG32:{} \;
      find $PWD/bitmaps/Bibata-Modern-Koru -name '*.png' -exec convert {} -fuzz 12% -fill '${theme.accent}' -opaque '#FFFFFF' -type TrueColorMatte PNG32:{} \;

      ctgen configs/normal/x.build.toml -p x11 \
        -d $PWD/bitmaps/Bibata-Modern-Koru \
        -n 'Bibata-Modern-Koru' \
        -c 'Bibata Modern recolored to the global theme accent' \
        -o $PWD/themes

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -dm 0755 $out/share/icons
      cp -rf $PWD/themes/Bibata-Modern-Koru $out/share/icons/
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Bibata Modern cursor recolored to the global theme colors";
      homepage = "https://github.com/ful1e5/Bibata_Cursor";
      license = licenses.gpl3Only;
      platforms = platforms.linux;
    };
  };
in
{
  # Single cursor definition for the session: home-manager derives the GTK
  # cursor (gtk.enable) from it and exports XCURSOR_THEME/-SIZE via
  # home.sessionVariables, so the name/size is not repeated in gtk.nix or
  # niri.nix (niri reads the theme through its `cursor` config block).
  home.pointerCursor = {
    enable = true;
    name = theme.cursor-name;
    package = koruCursor;
    size = theme.cursor-size;
    gtk.enable = true;
  };
}
