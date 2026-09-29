# --- flake ---
# NixOS flake: flake-parts composition + home-manager.
#
# One selection decides what the user layer installs: home/module-selection.nix, one
# boolean per home module (the single switchboard and the inventory of what
# home/ can install). home/default.nix asserts it matches the module directory.
#
# Outputs:
#   - nixosConfigurations.<host> : full system, with home-manager embedded for
#     that host, switchboard from home/module-selection.nix.
#   - homeConfigurations.<host>  : user layer only, switchboard as-is. Can be
#     switched at runtime (`home-manager switch --flake .#<host>`).
#   - homeConfigurations.all     : every user module forced on, evaluation
#     only, so a disabled/unsupported module cannot rot unnoticed.
{
  description = "NixOS configuration (flake-parts + home-manager)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    opencode = {
      url = "github:anomalyco/opencode/dev";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen browser (removed from nixpkgs; community-maintained flake:
    # https://github.com/0xc000022070/zen-browser-flake). Follows our nixpkgs
    # and home-manager; the flake assumes nixpkgs-unstable, which we are on.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # GitHub acceleration hosts, pinned by flake.lock; refresh manually via
    # `nix flake update github-hosts` (system.autoUpgrade is disabled).
    github-hosts = {
      url = "github:521xueweihan/GitHub520";
      flake = false;
    };

    # Provides `pkgs.rust-bin`, so the Rust toolchain can be pinned to an exact
    # version and installed declaratively (home/rust.nix).
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ROS 2 was dropped from nixpkgs; this community overlay provides
    # `rosPackages.<distro>` (home/ros2.nix). Deliberately NOT following our
    # nixpkgs: the overlay is generated against the revision it pins, so it is
    # built with its own (tested) nixpkgs in `mkRosPkgs` below.
    nix-ros-overlay = {
      url = "github:lopsided98/nix-ros-overlay/master";
    };

  };

  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      username = "wallyhao";
      theme = import ./system/theme.nix;

      hosts = import ./hosts/inventory.nix;

      overlays = [ inputs.rust-overlay.overlays.default ];

      # pkgs per target system: standalone home profiles and NixOS configs may
      # target different architectures once non-x86_64 hosts are added.
      # allowUnfree is repeated from system/nix-daemon.nix on purpose: standalone home
      # profiles use this separate pkgs instance (the embedded one reuses the
      # system set via useGlobalPkgs), so it must be set in both places.
      mkPkgs =
        system:
        import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };

      # ROS 2 packages need nix-ros-overlay applied. Keep that in a separate
      # pkgs instance built from the overlay's own nixpkgs pin, so the huge
      # Python/package overrides it carries cannot perturb the system set.
      mkRosPkgs =
        system:
        import inputs.nix-ros-overlay.inputs.nixpkgs {
          inherit system;
          overlays = [ inputs.nix-ros-overlay.overlays.default ];
          config.allowUnfree = true;
        };

      homeModules = [ ./home/default.nix ];

      # The user-layer switchboard (home/module-selection.nix) and its forced variant:
      # `all` turns every module on so nothing can rot unnoticed.
      homeEnabled = import ./home/module-selection.nix;
      enabledAll = homeEnabled // {
        enable = builtins.mapAttrs (_: _: true) homeEnabled.enable;
      };

      # extraSpecialArgs shared by the embedded and standalone home profiles.
      mkHomeSpecialArgs = enabled: host: {
        inherit
          inputs
          theme
          username
          enabled
          ;
        rosPkgs = mkRosPkgs host.system;
      };

      mkHost =
        name: host:
        nixpkgs.lib.nixosSystem {
          system = host.system;
          specialArgs = {
            inherit
              inputs
              theme
              username
              ;
            hostname = name;
          };
          modules = [
            ./hosts/${name}
          ]
          ++ [ ./system/default.nix ]
          ++ [
            inputs.home-manager.nixosModules.home-manager
            {
              nixpkgs.overlays = overlays;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-bak";
              home-manager.extraSpecialArgs = mkHomeSpecialArgs homeEnabled host;
              home-manager.users.${username} = {
                imports = homeModules;
              };
            }
          ];
        };

      mkHome =
        enabled: host:
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs host.system;
          extraSpecialArgs = mkHomeSpecialArgs enabled host;
          modules = homeModules;
        };

      # Working tree for the format/lint checks (no .git or editor junk).
      src = lib.cleanSource ./.;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ system ];

      flake.nixosConfigurations = lib.concatMapAttrs (name: host: {
        "${name}" = mkHost name host;
      }) hosts;

      flake.homeConfigurations =
        lib.concatMapAttrs (name: host: {
          "${name}" = mkHome homeEnabled host;
        }) hosts
        // {
          # Evaluation-only: every home module forced on, so a module no host
          # currently imports still fails CI the day it breaks. Built through
          # the same mkHome as the real profiles, so the two cannot drift.
          all = mkHome enabledAll { inherit system; };
        };

      perSystem =
        { pkgs, ... }:
        {
          formatter = pkgs.nixfmt;

          checks = {
            formatting =
              pkgs.runCommand "check-formatting"
                {
                  nativeBuildInputs = [ pkgs.nixfmt ];
                }
                ''
                  nixfmt --check $(find ${src} -name '*.nix' -type f)
                  touch $out
                '';

            lint =
              pkgs.runCommand "check-lint"
                {
                  nativeBuildInputs = [ pkgs.statix ];
                }
                ''
                  statix check --config ${src}/statix.toml ${src}
                  touch $out
                '';

            dead-code =
              pkgs.runCommand "check-dead-code"
                {
                  nativeBuildInputs = [ pkgs.deadnix ];
                }
                ''
                  deadnix --fail ${src}
                  touch $out
                '';
          };
        };
    };
}
