# --- rust ---
# Rust toolchain (rustc, cargo, rustfmt, clippy) installed declaratively and
# pinned to 1.98.1 through rust-overlay (a flake input locked in flake.lock),
# replacing the previous runtime `rustup` from `nix profile`.
#
# llvm-tools-preview rides along because cargo-llvm-cov needs llvm-profdata and
# llvm-cov matching rustc's own LLVM: the system LLVM 19 cannot read the profile
# data rustc 1.98 emits. The companion tools are the ones the project's `just`
# gates shell out to, and they are here rather than in a dev shell so that every
# checkout on this host can run them without a flake of its own.
{ pkgs, ... }:
let
  rust = pkgs.rust-bin.stable."1.98.1".default.override {
    extensions = [ "llvm-tools-preview" ];
  };
in
{
  home.packages = [
    rust
    pkgs.cargo-deny
    pkgs.cargo-llvm-cov
    pkgs.cocogitto
    pkgs.pre-commit
  ];
}
