{
  description = "Version-locked development tools for the koru profile";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Deliberately independent of our nixpkgs: ROS uses its tested package set.
    nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay/master";
  };

  outputs =
    {
      nixpkgs,
      rust-overlay,
      nix-ros-overlay,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
      };
      rosPkgs = import nix-ros-overlay.inputs.nixpkgs {
        inherit system;
        overlays = [ nix-ros-overlay.overlays.default ];
        config.allowUnfree = true;
      };
      tools = import ./default.nix { inherit pkgs rosPkgs; };
      rustTarget = pkgs.stdenv.hostPlatform.rust.rustcTarget;
      versions = pkgs.lib.mapAttrs (_: tool: tool.versions) tools;
      versionFile = pkgs.writeText "koru-dev-versions.json" (builtins.toJSON versions);
      bundle = pkgs.buildEnv {
        name = "koru-dev-tools";
        paths = pkgs.lib.concatMap (tool: tool.packages) (builtins.attrValues tools);
        passthru = {
          inherit versions;
          packageInventory = pkgs.lib.mapAttrs (
            _: tool:
            map (package: {
              name = package.pname or package.name;
              path = toString package;
            }) tool.packages
          ) tools;
        };
        postBuild = ''
          mkdir -p $out/share/koru-dev
          cp ${versionFile} $out/share/koru-dev/versions.json
        '';
      };
    in
    {
      packages.${system}.dev-tools = bundle;
      checks.${system} = (import ./toolchain-checks.nix { inherit pkgs bundle versions; }) // {
        rust-version =
          pkgs.runCommand "check-profile-rust"
            {
              nativeBuildInputs = [ pkgs.stdenv.cc ];
            }
            ''
              export PATH=${bundle}/bin:$PATH
              ${bundle}/bin/rustc --version | ${pkgs.gnugrep}/bin/grep -F 'rustc ${versions.rust.rustc} '
              ${bundle}/bin/cargo --version
              ${bundle}/bin/rustfmt --version
              ${bundle}/bin/cargo-clippy --version
              ${bundle}/bin/cargo llvm-cov --version
              test -f ${bundle}/lib/rustlib/${rustTarget}/bin/llvm-profdata
              export HOME=$TMPDIR/home
              mkdir -p "$HOME" smoke/src
              cd smoke
              cat > Cargo.toml <<'TOML'
              [package]
              name = "profile-smoke"
              version = "0.1.0"
              edition = "2024"
              TOML
              cat > src/lib.rs <<'RUST'
              pub fn answer() -> u32 { 42 }
              #[test]
              fn works() { assert_eq!(answer(), 42); }
              RUST
              cargo llvm-cov --offline --summary-only
              touch $out
            '';
      };
    };
}
