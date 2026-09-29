# NixOS · koru

NixOS and Home Manager configuration for `wallyhao@koru`. The desktop uses Niri,
and dependency versions are pinned by `flake.lock`. System modules, user
software and hardware identity are managed separately; the shared theme lives in
[`system/theme.nix`](system/theme.nix).

## Daily operations

The repository `Justfile` is the documented interface. Run `just` to list all
recipes; build, test, activation, rollback and cleanup remain separate actions.
For example:

```sh
cd ~/.config/nixos

# Evaluate and build without activation
just configuration-evaluate
just system-configuration-build

# Apply the system and embedded Home Manager profile after review
just system-configuration-switch

# Apply only the standalone user profile, without sudo
just home-configuration-switch
```

Expensive recipes are AC-only by default; pass `allow_battery=true` only as an
explicit manual override. `system-configuration-test` can restart services even
though the generation is temporary. A Git flake only includes registered files:
after adding or renaming files, review `git status` and use
`git add --intent-to-add <new file>` before local evaluation. Recipes never
update `flake.lock` or stage files implicitly.

## Directories and responsibilities

| Location | Responsibility |
| --- | --- |
| `flake.nix` | Inputs, package set, system and user outputs, check tasks |
| `flake.lock` | Pins dependency versions; refactors must not update it incidentally |
| `hosts/inventory.nix` | Host names and CPU architecture inventory |
| `hosts/koru/default.nix` | Host module entry, hostname and stateVersion |
| `hosts/koru/hardware-configuration.nix` | Generated devices, UUIDs, filesystems and hardware probing |
| `hosts/koru/boot.nix` | Bootloader, initrd, kernel parameters and driver blacklist |
| `hosts/koru/btrfs-mounts.nix` | Btrfs compression, access time and TRIM mount policy |
| `hosts/koru/locale.nix` | Timezone, locale and keyboard layout |
| `hosts/koru/user-account.nix` | User, login shell, password source and TTY autologin |
| `system/default.nix` | **Explicit** system module list |
| `system/theme.nix` | Shared data for colors, fonts, cursor and sizes; not a NixOS module |
| `home/default.nix` | Home Manager base config, module discovery and switch validation |
| `home/module-selection.nix` | User module install switches, one boolean per file |
| `home/<software>.nix` | Install and configuration for that software |
| `home/niri/` | Niri launcher, idle dimming and keybindings |
| `home/dotfiles/` | Non-Nix files referenced by modules |
| `lib/module-discovery.nix` | User module discovery function |
| `lib/home-module-dependencies.nix` | Valid cross-module dependency combinations |
| `lib/wmenu-style.nix` | Generate wmenu arguments from the shared theme |
| `scripts/` | Maintenance, module editing, proxy and Field Notes logic |
| `completions/` | Repository-owned shell completions |
| `.github/workflows/check.yml` | Format, static analysis and config evaluation CI |

`default.nix` is only a directory entry, and its role is defined by its parent
directory; other files are named after a concrete function or piece of software.
System modules may affect services immediately on `switch`, so they are not
"boot-time only"; user modules may contain long-running user services, so they
are not "login-time only".

## System module index

| File | Manages |
| --- | --- |
| `niri-session.nix` | Niri system session registration and the FUSE tools the portal needs |
| `display-power.nix` | Screen brightness and refresh rate on AC/battery, and systemd tasks |
| `console.nix` / `fonts.nix` | TTY font and palette / font installation and fontconfig |
| `fcitx5-rime.nix` | Fcitx5, the Rime engine and input method environment variables |
| `pipewire-audio.nix` | PipeWire, ALSA/Pulse compatibility and realtime scheduling |
| `intel-graphics.nix` | Intel rendering, video acceleration and GuC parameters |
| `gpu-screen-recorder.nix` | Recording tool and its KMS permission wrapper |
| `bluetooth-disabled.nix` | Disable the Bluetooth service and block the Bluetooth radio |
| `power-management.nix` | CPU power policy, thermald, UPower, Powertop and USB exceptions |
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
and is **not** placed in the system imports. Alacritty, GTK, the cursor, the TTY,
editors and menus all read the same semantic colors.

Niri file responsibilities:

- `system/niri-session.nix`: installs and registers the system session.
- `home/tty-login.nix`: starts `niri-session` from the tty1 login shell.
- `home/niri.nix`: layout, input devices, window rules and startup programs.
- `home/niri/keybindings.nix`: keybinding map, imported as data.
- `home/niri/application-launcher.nix`: wmenu launcher sorted by frequency and recency.
- `home/niri/idle-dimming.nix`: idle dimming and restore.
- `system/display-power.nix`: power events are submitted to systemd via udev; no long IPC in udev.

Retained behavior: Alt is the modifier, Alt+arrows move focus, Alt+Shift+arrows
move windows/columns, and Alt+Tab opens the overview. Brightness policy is still
60% on battery and 100% on AC; the refresh rate picks the value closest to
60/144 Hz among the available 1920×1080 modes. It is not a generic multi-monitor
setup.

## Module switches and adding files

Keys in `home/module-selection.nix` must match the module file names directly
under `home/`, with the `.nix` suffix removed; `default.nix` and
`module-selection.nix` are excluded. Values must be booleans. A missing key, an
unknown key or a non-boolean value fails evaluation.

For example `c-cpp-toolchain`, `java-toolchain`, `clipboard-history`,
`cursor-theme`, `tty-login` and `zen-browser` all correspond to files of the same
name. When deleting a module, delete its switch too. Helper files under
`home/niri/` are imported by `home/niri.nix` and are not scanned by the top-level
switchboard. Known command dependencies are asserted, so an invalid combination
fails before the switchboard is replaced.

Use the transactional commands rather than editing booleans mechanically:

```sh
just home-modules-list
just home-module-disable name=libreoffice
just home-module-enable name=libreoffice
just home-modules-validate
```

Enable/disable validates syntax, inventory, dependency rules and a temporary
copy of the selected Home Manager output. It does not activate a profile.

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
just configuration-format-check
just configuration-lint-check
just configuration-dead-code-check
just configuration-check

# Return to the previous system generation
just system-generation-rollback
```

`nixosConfigurations.koru` includes the system and the embedded Home Manager;
`homeConfigurations.koru` is the standalone user config; `homeConfigurations.all`
forces every user module to evaluate, for checks. `nix flake check` does not
automatically check arbitrarily named `homeConfigurations` outputs, so CI
evaluates them separately. Syntax check, successful evaluation, successful build
and a working desktop are distinct verification stages.

Rolling back the system does not revert repository file changes; the standalone
Home Manager generation has its own lifecycle. GC runs daily at 03:15, only on
AC, and cleans generations older than seven days per the current policy; the
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

## On-demand global proxy (Mihomo)

The system module `system/mihomo.nix` installs the Mihomo TUN service and
`proxyctl`, not started at boot by default. Fill a Mihomo/Clash-compatible
subscription URL into `~/.config/mihomo/subscription-url` (one URL per file); the
file mode is `0600` and it is not tracked by Git or the Nix store. The proxy
runtime config is not committed and is written to `/etc/mihomo/config.yaml`.

After switching to this NixOS config, run inside NixOS:

```sh
proxyctl refresh   # fetch the subscription, probe google.com per node, build the usable node table
proxyctl start     # pick a node with up/down keys (Enter to confirm), start the global TUN proxy
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

`refresh` keeps only nodes that can reach Google, sorted by latency, US first,
written to `~/.config/mihomo/nodes.json`; the normalized subscription is written
to `~/.config/mihomo/provider.yaml` and handed to Mihomo via a systemd
credential, so it does not download by itself before the proxy works. `start`
lists only these usable nodes and uses the selection as the global egress. After
changing the subscription URL, re-run `proxyctl refresh`; on start failure,
inspect with `journalctl -u mihomo -b`.

## Input switching and Field Notes

Rime is configured so tapping either Shift key commits the raw Latin code before
switching its ASCII mode. Framework switching uses `CommitRawInput`; keep that
action on a distinct shortcut such as the default Ctrl+Space. After a Home
Manager switch, redeploy/reload Rime and verify both Shift keys in terminal,
browser, GTK and Qt applications—evaluation cannot test key routing.

`field-notes` prints one on-demand power snapshot with AC state, battery rate,
brightness, refresh rate, CPU governor/EPP, network state and load average. It
does not poll or change policy. Record controlled baselines with a label that
describes fixed brightness, refresh rate, network state and workload:

```sh
field-notes show
field-notes --json
field-notes record 'battery-60pct-60hz-wifi-idle'
```

Recorded JSON lines live in `~/.local/state/koru/field-notes.jsonl` with private
permissions. This configuration keeps auto-cpufreq as the sole CPU policy owner;
it does not add TLP or power-profiles-daemon, and the theme makes no battery-life
claim.
