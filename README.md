# NixOS · koru

NixOS and Home Manager configuration for user `koru` on host `koru`. The desktop uses Niri,
and dependency versions are pinned by `flake.lock`. System modules, user
software and hardware identity are managed separately; the shared theme lives in
[`system/theme.nix`](system/theme.nix).

## Daily operations

The `koru` CLI is installed with the user configuration and works from any
directory. It targets this repository's `koru` configuration. Rollback requires
`--generation ID`; module enable/disable require one or more module names.
Other commands take no arguments.

```sh
koru system check                  # build without activation
koru system build                  # build and switch together
koru system list                   # retained generations; * marks current
koru system rollback --generation 123

koru home check                    # standalone user configuration
koru home build                    # build and switch together
koru home list
koru home rollback --generation 45
koru home modules                  # enabled and disabled user modules
koru home disable libreoffice zen-browser
koru home enable libreoffice
koru home validate                 # validate without activation

koru profile check                 # build development tools without installing
koru profile build                 # install/update the locked development bundle
koru profile status                # installed versions and source agreement
koru profile list                  # retained development profile generations
koru profile rollback --generation 1

koru proxy status                  # local state; no external measurements
koru proxy list                    # cached nodes and cached delays
koru proxy refresh                 # refresh; restore an active proxy
koru proxy start                   # interactive node selection
koru proxy stop
koru proxy autostart               # unattended Hong Kong selection

koru store status
koru store gc                      # collect garbage; preserve generations
koru --help
```

`check` performs a real build without activating it or creating a result link;
it cannot verify the running desktop or services. Rollback activates a retained
generation without reverting source files. System rollback also updates the
boot default. System operations include embedded Home Manager, while `home`
operations manage its standalone profile.

`proxy start` requires a terminal. Canceling selection leaves the service
unchanged. `proxy refresh` temporarily stops an active proxy and restores its
previous node. If that node is absent from the refreshed usable-node list, it
keeps the old cache and attempts restoration rather than selecting another
node. `store gc` uses sudo and never deletes retained generations.

CLI text is English, with colors taken from `system/theme.nix`. Output adapts
to the terminal width, using stacked fields in narrow windows and truncating
long display values. Node selection still uses full names. Redirected output
and `NO_COLOR` disable ANSI colors. Build and maintenance logs are wrapped for
display; complete logs are stored privately under
`${XDG_STATE_HOME:-~/.local/state}/koru/operation.*.log`.

Implementation lives in `scripts/koru.sh` and `scripts/koru/`; Nix packaging
lives in `lib/koru-package.nix`. Before the first activation, run
`bash scripts/koru.sh --help` directly from the repository. New source files
must be registered with Git before a Git-flake build includes them.

### Lower-level scripts

Run the repository scripts directly; build, test, activation, rollback and
cleanup remain separate actions. For example:

```sh
cd ~/.config/nixos

# Evaluate and build without activation
./scripts/maintenance.sh configuration-evaluate koru
./scripts/maintenance.sh system-configuration build koru

# Apply the system and embedded Home Manager profile after review
./scripts/maintenance.sh system-configuration switch koru

# Apply only the standalone user profile, without sudo
./scripts/maintenance.sh home-configuration switch koru
```

Builds, activation and manual maintenance work on either AC or battery.
`system-configuration test` can restart services even
though the generation is temporary. A Git flake only includes registered files:
after adding or renaming files, review `git status` and use
`git add --intent-to-add <new file>` before local evaluation. Scripts never
update `flake.lock` or stage files implicitly.

## Directories and responsibilities

| Location | Responsibility |
| --- | --- |
| `flake.nix` | Inputs, package set, system and user outputs, check tasks |
| `flake.lock` | Pins dependency versions; refactors must not update it incidentally |
| `profile/` | Independently locked development tools installed through a dedicated Nix profile |
| `hosts/inventory.nix` | Host names and CPU architecture inventory |
| `hosts/koru/default.nix` | Host module entry, hostname and stateVersion |
| `hosts/koru/hardware-configuration.nix` | Generated devices, UUIDs, filesystems and hardware probing |
| `hosts/koru/boot.nix` | Bootloader, initrd, kernel parameters and driver blacklist |
| `hosts/koru/btrfs-mounts.nix` | Btrfs compression, access time and TRIM mount policy |
| `hosts/koru/locale.nix` | Timezone, locale and keyboard layout |
| `hosts/koru/display-power.nix` / `power-management.nix` | Panel, CPU, thermal and peripheral power policy for this laptop |
| `hosts/koru/intel-graphics.nix` / `bluetooth.nix` | Device-specific graphics and Bluetooth policy |
| `hosts/koru/user-account.nix` | User, login shell, password source and TTY autologin |
| `system/default.nix` | **Explicit** system module list |
| `system/theme.nix` | Shared data for colors, fonts, cursor and sizes; not a NixOS module |
| `home/default.nix` | Home Manager base config, module discovery and switch validation |
| `home/modules-enables.nix` | User module install switches, one boolean per file |
| `home/<software>.nix` | Install and configuration for that software |
| `home/niri/` | Niri launcher, idle dimming and keybindings |
| `home/dotfiles/` | Non-Nix files referenced by modules |
| `lib/module-discovery.nix` | User module discovery function |
| `lib/home-module-dependencies.nix` | Valid cross-module dependency combinations |
| `lib/wmenu-style.nix` | Generate wmenu arguments from the shared theme |
| `scripts/` | Maintenance, module editing and proxy logic |
| `completions/` | Repository-owned shell completions |
| `.github/workflows/check.yml` | Format, static analysis, failure recovery tests and real system/user builds |

`default.nix` is only a directory entry, and its role is defined by its parent
directory; other files are named after a concrete function or piece of software.
System modules may affect services immediately on `switch`, so they are not
"boot-time only"; user modules may contain long-running user services, so they
are not "login-time only".

## System and host module index

| File | Manages |
| --- | --- |
| `niri-session.nix` | Niri system session registration and the FUSE tools the portal needs |
| `hosts/koru/display-power.nix` | Screen brightness and refresh rate on AC/battery, and systemd tasks |
| `console.nix` / `fonts.nix` | TTY font and palette / font installation and fontconfig |
| `fcitx5-rime.nix` | Fcitx5, the Rime engine and input method environment variables |
| `pipewire-audio.nix` | PipeWire, ALSA/Pulse compatibility and realtime scheduling |
| `hosts/koru/intel-graphics.nix` | Intel rendering, video acceleration and GuC parameters |
| `gpu-screen-recorder.nix` | Recording tool and its KMS permission wrapper |
| `hosts/koru/bluetooth.nix` | Disable the Bluetooth service and block the Bluetooth radio |
| `hosts/koru/power-management.nix` | CPU power policy, thermald, UPower, Powertop and USB exceptions |
| `memory-zram.nix` | zram, memory reclaim parameters and systemd-oomd; do not add disk swap untuned |
| `network-manager.nix` | NetworkManager, Wi-Fi power saving, DNS and online-wait policy |
| `mihomo.nix` | On-demand TUN global proxy and the `proxyctl` command |
| `tcp-tuning.nix` | TCP, queueing discipline and IPv4 hardening parameters |
| `time-servers.nix` | NTP server list |
| `github-hosts.nix` | Version-pinned static GitHub hosts override |
| `firewall.nix` | Application ingress ports; currently allows TCP 8080 |
| `openssh-server.nix` | SSH authentication, service and TCP 22 firewall ingress |
| `nix-daemon.nix` | Nix cache, trust, build parallelism and low-disk cleanup threshold |
| `nix-garbage-collection.nix` | Scheduled GC, power conditions and manual upgrade policy |
| `journal-limits.nix` | systemd journal size cap |
| `zsh-login-shell.nix` | System-layer Zsh support; interactive config lives in `home/zsh.nix` |

## Theme and desktop

To change the theme, edit only `system/theme.nix`. It stays pure data, passed to
the system and user layers via the flake's `specialArgs` / `extraSpecialArgs`,
and is **not** placed in the system imports. Kitty, GTK, the cursor, the TTY,
editors and menus all read the same semantic colors.

Niri file responsibilities:

- `system/niri-session.nix`: installs and registers the system session.
- `home/tty-login.nix`: starts `niri-session` from the tty1 login shell.
- `home/niri.nix`: layout, input devices, window rules and startup programs.
- `home/niri/keybindings.nix`: keybinding map, imported as data.
- `home/niri/application-launcher.nix`: wmenu launcher sorted by frequency and recency.
- `home/niri/idle-dimming.nix`: idle dimming and restore.
- `hosts/koru/display-power.nix`: power events are submitted to systemd via udev; no long IPC in udev.

Retained behavior: Alt is the modifier, Alt+arrows move focus, Alt+Shift+arrows
move windows/columns, and Alt+Tab opens the overview. Brightness policy is still
60% on battery and 100% on AC; the refresh rate picks the value closest to
60/144 Hz among the available 1920×1080 modes. It is not a generic multi-monitor
setup.

After five minutes of inactivity, the internal backlight is dimmed to at most
10%, with its previous brightness saved. After ten minutes of inactivity, Niri
powers off all monitors. Activity turns the monitors back on and restores the
saved brightness instead of resetting it to the AC/battery default. An already
lower brightness is kept. This idle policy does not suspend the system; startup
and AC/battery transitions still apply the separate display power profile.

## Module switches and adding files

Rust, C/C++, Java, Node.js, Python tools (uv/Ruff), OpenMPI, ROS 2, Typst and
Just are managed by [`profile/`](profile/README.md), outside the Home Manager
switchboard. Its own flake and lock file decouple tool updates from system
updates. Use `koru profile build` to apply its explicit inventory. Home Manager
provides the profile's session PATH and Zsh completion search path; software
versions and completion files follow the installed profile generation.

Keys in `home/modules-enables.nix` must match the module file names directly
under `home/`, with the `.nix` suffix removed; `default.nix` and
`modules-enables.nix` are excluded. Values must be booleans. A missing key, an
unknown key or a non-boolean value fails evaluation.

For example `clipboard-history`,
`cursor-theme`, `tty-login` and `zen-browser` all correspond to files of the same
name. When deleting a module, delete its switch too. Helper files under
`home/niri/` are imported by `home/niri.nix` and are not scanned by the top-level
switchboard. Known command dependencies are asserted, so an invalid combination
fails before the switchboard is replaced.

Use the transactional commands rather than editing booleans mechanically:

```sh
koru home modules
koru home disable libreoffice zen-browser
koru home enable libreoffice
koru home validate
koru home build
```

Enable/disable validates syntax, inventory, dependency rules and a temporary
copy of the selected Home Manager output. It does not activate a profile.
Batch edits are atomic: every requested change is evaluated together before
the switchboard is replaced. Unknown names or invalid dependencies leave the
original file untouched. Only `home/modules-enables.nix` controls module
selection; disabled module sources and user-created data remain available.

Optional integrations follow the same switches. Disabling LibreOffice removes
`topdf`; disabling the browser removes its Zsh helper and Niri shortcut.
Fastfetch/Btop startup windows, input-method startup, image/clipboard/screenshot
shortcuts, Bat/Eza aliases and Fzf widgets are generated only when their owning
modules are enabled. Essential dependencies remain explicit: Fzf needs Fd and
Zsh; TTY autologin into the desktop needs Niri and Zsh. Management tools remain
installed independently of the software switches. System-installed packages
and dependencies of other modules may still exist after a user module is disabled.

When adding a system module, register the file explicitly in
`system/default.nix`. Do not mix data or utility functions into imports; put
shared utilities in `lib/`, and device-specific policy in `hosts/koru/`.

## Update, checks and rollback

```sh
# Review the worktree before updating; review the lock file after
git status --short
nix flake update                  # or only: nix flake update github-hosts
git diff -- flake.lock

# Non-mutating checks
./scripts/maintenance.sh configuration-format-check
./scripts/maintenance.sh configuration-lint-check
./scripts/maintenance.sh configuration-dead-code-check
./scripts/maintenance.sh configuration-check

# Return to the previous system generation
./scripts/maintenance.sh system-generation-rollback
```

`nixosConfigurations.koru` includes the system and the embedded Home Manager;
`homeConfigurations.koru` is the standalone user config; `homeConfigurations.all`
forces every user module to evaluate, for checks. `nix flake check` does not
automatically check arbitrarily named `homeConfigurations` outputs, so CI
evaluates them separately. The `proxy-lifecycle` flake check boots an isolated NixOS VM and tests real
sudo authorization, systemd credentials, TUN startup, successful refresh,
failed-refresh recovery and shutdown against a loopback HTTP fixture. CI also
builds the full system closure and the standalone user activation package
after checks and tests pass. Syntax check, successful evaluation,
successful build and a working desktop are distinct verification stages; CI
does not activate the laptop configuration or exercise physical hardware.

Rolling back the system does not revert repository file changes; the standalone
Home Manager generation has its own lifecycle. GC runs daily at 03:15
and cleans generations older than seven days per the current policy; the
rollback range is limited by this. `system.stateVersion` and `home.stateVersion`
are compatibility baselines and do not change with dependency updates.

## Retained local policy

This directory refactor keeps the existing user account, password source,
autologin, SSH access policy, network parameters and software selection.
`hosts/koru/password` is still read by `user-account.nix`; it is a plaintext file
and enters Nix evaluation data, so this repository should not be treated as a
secret-free template that can be published as-is.

SSH still allows password login and disables root login; the firewall opens 22
and 8080. The network still uses static DNS, the GitHub hosts override and the
existing TCP parameters. The earlier nixos2 Qtile config was not migrated;
Mihomo uses a separate on-demand module.

## Global proxy and startup dashboard (Mihomo)

The system module `system/mihomo.nix` installs the Mihomo TUN service and
`proxyctl`. Fill a Mihomo/Clash-compatible subscription URL into
`~/.config/mihomo/subscription-url` (one URL per file); the file mode is `0600`
and it is not tracked by Git or the Nix store. The proxy runtime config is not
committed and is written to `/etc/mihomo/config.yaml`.

When the graphical Niri session starts, proxy bootstrap runs in the background
without a window: `proxyctl autostart` refreshes the cache when needed and
selects the lowest-latency Hong Kong node (`香港`, `Hong Kong`, `HK`/`HKG` or
`🇭🇰`) before enabling the global TUN. `system/mihomo.nix` grants that user a
passwordless `sudo` rule scoped to proxyctl's internal `__enable` subcommand, so
the windowless autostart can restart Mihomo; every other privileged proxyctl
operation still prompts. The scratch workspace holds the startup dashboard: a
`fastfetch` terminal opens on the left and a full-width `btop` column opens on
its right.

After switching to this NixOS config, run inside NixOS:

```sh
proxyctl refresh   # fetch the subscription, probe google.com per node, build the usable node table
proxyctl start     # pick a node with up/down keys (Enter to confirm), start the global TUN proxy
proxyctl autostart # use the lowest-latency Hong Kong node without prompting
proxyctl nodes     # list the local cache and its cached latency values
proxyctl status    # local service/controller/TUN/cache state; no external probe
proxyctl shutdown  # stop the service and TUN
```

An active proxy is not interrupted by `refresh` unless `--restore` is supplied.
`status --latency`, `status --traffic` and `status --speed-test` are explicit,
bounded measurements; the last one transfers at most 10 MiB for at most 15
seconds through `127.0.0.1:7890`. `status --json` is uncolored and machine
readable. Zsh completion reads node names only from the local cache and performs
no network or privileged work.

`refresh` keeps only nodes that can reach Google, sorted with Hong Kong nodes
first and then by latency, written to `~/.config/mihomo/cache/current/nodes.json`; the normalized subscription is written
to `~/.config/mihomo/cache/current/provider.yaml` and handed to Mihomo via a systemd
credential, so it does not download by itself before the proxy works. `start`
lists only these usable nodes and uses the selection as the global egress. After
changing the subscription URL, re-run `proxyctl refresh`; on start failure,
inspect with `journalctl -u mihomo -b`.

Proxy mutations (`start`, `autostart`, `refresh`, `shutdown`) share a
nonblocking operation lock; a second operation fails without changing state.
Privileged helpers also serialize service changes. The default latency target
remains Google; `koru.proxy.latencyUrl` can set another HTTP test endpoint. Read-only status and node
listing remain available during refresh. Each successful refresh publishes an
immutable cache generation through one atomic `cache/current` symlink change.
Legacy `provider.yaml` and node caches are migrated when needed. The original
`provider.yaml` path becomes a compatibility symlink, so existing systemd
credentials continue to work across the first upgrade. If restarting
the previous node fails after publication, recovery switches back to the old
cache before trying the old node again. SIGINT/SIGTERM trigger the same cleanup;
SIGKILL and power loss cannot run cleanup. Cache generations are retained for
recovery and readers; they can contain subscription credentials and stay private.

## Input switching

Rime is configured so tapping either Shift key commits the raw Latin code before
switching its ASCII mode. Framework switching uses `CommitRawInput`; keep that
action on a distinct shortcut such as the default Ctrl+Space. After a Home
Manager switch, redeploy/reload Rime and verify both Shift keys in terminal,
browser, GTK and Qt applications—evaluation cannot test key routing.
