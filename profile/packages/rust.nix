{ pkgs }:
let
  version = "1.98.1";
  rust = pkgs.rust-bin.stable.${version}.default.override {
    extensions = [ "llvm-tools-preview" ];
  };
in
assert pkgs.lib.assertMsg (
  rust.version == version
) "Rust profile requires ${version}, got ${rust.version}";
{
  packages = [
    rust
    pkgs.cargo-deny
    pkgs.cargo-llvm-cov
    pkgs.cocogitto
    pkgs.pre-commit
  ];
  versions = {
    rustc = version;
    cargo-deny = pkgs.cargo-deny.version;
    cargo-llvm-cov = pkgs.cargo-llvm-cov.version;
    cocogitto = pkgs.cocogitto.version;
    pre-commit = pkgs.pre-commit.version;
  };
}
