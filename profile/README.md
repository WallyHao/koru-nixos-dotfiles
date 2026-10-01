# Development profile

This independent flake installs version-locked development tools through one
dedicated Nix profile. It owns Rust, C/C++, Java, Node.js, uv/Ruff, OpenMPI,
ROS 2, Typst and Just. Home Manager owns session PATH, Zsh completion discovery
and editor/user configuration.

## Sources and versions

- `flake.nix`: independent nixpkgs and overlay inputs, bundle output and checks.
- `flake.lock`: exact input revisions and hashes, tracked in Git independently
  of the system lock. Initial pins match the previous Home Manager setup;
  migration preserves the existing package output paths and versions.
- `default.nix`: explicit installation inventory; add/remove entries here.
- `packages/<name>.nix`: packages, version constraints and reported versions.

Rust is pinned to **1.98.1**, with `llvm-tools-preview`, cargo-deny,
cargo-llvm-cov, cocogitto and pre-commit. Companion versions and dependencies
are locked by nixpkgs. The exact Rust version is also asserted during evaluation.

| Inventory entry | Tools and version policy |
| --- | --- |
| `c-cpp-toolchain` | GCC multilib, LLVM/Clang 19, clangd, build/debug tools; GCC owns cc/c++ |
| `java-toolchain` | JDK 21; major version asserted |
| `nodejs` | Node.js 22 and npm; major version asserted |
| `python` | uv and Ruff; project Python versions/dependencies remain project-owned |
| `openmpi` | Runtime and dev outputs, including compiler wrappers |
| `ros2` | Humble, colcon and existing ROS buildEnv; overlay's own nixpkgs retained |
| `rust` | Rust 1.98.1 and companion tools |
| `typst` | Typst CLI, locked by nixpkgs |
| `just` | Just and its matching Zsh completion, locked by nixpkgs |

ROS has a separate `ros-nixpkgs` lock node because its overlay is tested against
that revision. Updating the main profile nixpkgs does not change ROS's package
set. Update the ROS overlay and review its transitive locks explicitly when
needed; it does not follow the main profile nixpkgs.

All entries are merged into `packages.x86_64-linux.dev-tools`. Packages that
share a nixpkgs input update together when that input changes. If a future tool
must remain on an older package set, give it a separate pinned input. Changing
a derivation's `version` field alone does not select another source release.

## Operations

```sh
koru profile check                       # real build; no installation
koru profile build                       # install or update the bundle
koru profile status                      # installed versions and source agreement
koru profile list                        # retained generations
koru profile rollback --generation 1
```

Before activating the updated Home Manager CLI, use
`bash scripts/koru.sh profile <action>` from the repository.

The runtime profile is
`${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/koru-dev`. The new Home Manager
configuration adds its `bin` directory to the session PATH and its
`share/zsh/site-functions` to Zsh's fpath before completion initialization.
Just's completion follows the installed bundle, including rollback. Until that
configuration is activated, add the same directory to PATH for the current
shell when verifying the installed tools. Profile installation itself needs
neither sudo nor a system rebuild.

The managed profile contains exactly one `dev-tools` element from this local
flake. Do not add individual packages to it manually. Build refuses unrelated
entries or a bundle from a different source. Nix builds the bundle before
publishing the next generation, so failure preserves the installed generation.
All mutations use the shared Koru operation lock. Direct Nix commands bypass
that lock and should not run concurrently with Koru commands.

Status evaluates the desired output path without building, updating inputs or
probing the network deliberately; Nix may fetch uncached locked inputs. Version
metadata is read from the installed bundle, so a rollback reports old versions
accurately. Rollback changes the installed profile, not the source or lock file.
The next build reapplies current source. Generations are not explicitly pruned
by Koru; system Nix GC policy may still expire profile history. Retain important
versions with an explicit GC root if needed.

## Updating versions

From this directory:

```sh
nix flake update rust-overlay             # only this input
git diff -- flake.lock packages/
nix flake check --no-update-lock-file path:.
koru profile check
koru profile build
```

For an exact Rust upgrade, change `version` in `packages/rust.nix` too. Upgrade
nixpkgs explicitly when needed with `nix flake update nixpkgs`, and review all
companion version changes. Normal operations use `--no-update-lock-file` and
never update inputs automatically. Commit definitions and the lock together.

Add a tool by defining its packages and version metadata under `packages/`, then
registering it in `default.nix`. Build the profile before removing its old Home
Manager installation. Do not install the same tool through both managers in the
final configuration. Package profiles expose files; tools requiring environment
variables or setup hooks need explicit wrappers or a development shell.

## Validation

CI runs the independent flake checks as well as the system checks. Checks cover
GCC/Clang compilation, 32-bit linking/execution, LLVM IR tools, Java compilation,
Node/npm, uv virtual environments and Ruff, a two-process MPI program, ROS CLI
and colcon CMake builds, Typst PDF output and Just execution/completion. The Rust
check runs the compiler, Cargo, rustfmt, Clippy and cargo-llvm-cov, and checks for
the matching LLVM profiling tools, then compiles and measures coverage of a
dependency-free Rust fixture. `tests/profile/run.sh` uses real Nix profiles
and tiny temporary derivations to verify initial installation, version changes,
failed-build preservation, exact-generation rollback and rejection of unmanaged
or foreign entries. It does not activate the host configuration.
