<h2 align="center">:snowflake: Koru - NixOS Configuration :snowflake:</h2>

<p align="center">
  <img src="assets/fastfetch/koru-logo.png" alt="Koru logo" width="240" />
</p>

<p align="center">
  <a href="https://nixos.org/"><img alt="NixOS 26.11" src="https://img.shields.io/badge/NixOS-26.11-informational.svg?style=for-the-badge&logo=nixos&color=8FBF88&logoColor=D2DCD0&labelColor=171E1A"></a>
  <a href="https://github.com/YaLTeR/niri"><img alt="Niri" src="https://img.shields.io/badge/WM-Niri-informational.svg?style=for-the-badge&color=8FBF88&labelColor=171E1A"></a>
  <a href="https://github.com/nix-community/home-manager"><img alt="Home Manager" src="https://img.shields.io/badge/Home%20Manager-managed-informational.svg?style=for-the-badge&color=8FBF88&labelColor=171E1A"></a>
</p>

> This is a personal, single-machine configuration. It targets one laptop and reads a local
> password file, so it is **not a general-purpose template**. Read it as a reference and take the
> parts that fit your own hardware and habits.

This repository builds the NixOS, Home Manager and development-tool configuration for my main
laptop. It targets `x86_64-linux` and runs the [Niri] Wayland compositor.

- **System layer** - `nixosConfigurations.koru`: NixOS unstable with `system.stateVersion = "26.11"`,
  [Niri], [Fcitx5]+[Rime], zram, Btrfs, and battery-first power tuning.
- **User layer** - Home Manager, driven by a single switchboard (`home/modules-enables.nix`) that
  decides which software is installed. It can also be switched on its own.
- **Development tools** - an independently locked Nix profile (`profile/`) so compilers and runtimes
  update without rebuilding the system.

See [`hosts/`](./hosts) for the device registry, [`home/`](./home) for user modules,
[`profile/`](./profile) for the toolchain, [`system/`](./system) for system modules, and
[`flake.nix`](./flake.nix) for the outputs.

## Why NixOS and Niri

I have used Ubuntu, Debian, Kali, Arch and NixOS. I first met NixOS while setting up a desktop
environment on Debian and getting fed up with dependency conflicts. Later, when I wanted to switch
to [Niri], I found that Niri's original author uses NixOS himself, so I started using NixOS too.

NixOS is now my favorite distribution. I like writing system settings directly into configuration,
and I like a maintenance model I can inspect and roll back. It is not without drawbacks: installing
and using software often takes an extra step, and prebuilt packages do not always work as-is. NixOS
does not follow the traditional FHS (Filesystem Hierarchy Standard) layout, so packages and binaries
built for Debian or Red Hat usually need adapting instead of just running. For background, see the
[NixOS wiki][NixOS Wiki FAQ]. Whether the trade-off is worth it depends on your habits - for me, it
has paid off.

For the desktop, I have tried i3, Awesome, Sway, GNOME, KDE Plasma, Hyprland and [Niri], and I ended
up on Niri. Its scrolling layout fits this laptop screen: as more windows open, the ones already
placed do not have to shrink to fit on one screen, and I can simply move the viewport to the window
I want. For a small screen and my preference for large text, that is a big comfort, and the window
handling matches my intuition. I care about resource usage too, and in my experience Niri balances
features and overhead well - it needs little extra setup to handle daily use.

## Battery First

### The Machine

| Item | Configuration |
| --- | --- |
| Model | Lenovo Legion Y7000 IRX9 (`83JJ`) |
| CPU | 13th Gen Intel Core i7-13650HX (6P + 8E, HWP / EPP available) |
| Memory | 24 GB |
| Display | 1920x1080, 60 Hz and 144 Hz |
| Storage | Btrfs (`/`, `/home`, `/nix` subvolumes), no swap partition |

This laptop is a performance-oriented gaming machine, so battery life was never its strength. On
battery I trade some performance and refresh rate for longer runtime.

### Battery Life

These numbers are rough notes I took during class on the same machine and battery: reading and
writing files, looking things up in a browser, occasionally running an AI agent, no compilation,
brightness around 60%.

| System | State | Approximate runtime |
| --- | --- | --- |
| Windows | Power saving | ~2.5 h |
| Ubuntu | Defaults | ~1.5 h |
| NixOS (this config) | Normal use | ~4 h |

The numbers come from daily use, not a controlled benchmark, so treat them as personal experience.
What matters to me is that after tuning the power policy for this machine, leaving the charger at
home is much less stressful.

### Power Tuning

NixOS lets me write these adjustments into configuration, so I can inspect, change or redeploy them
later. I borrowed from [nyx], [Misterio77] and [ryan4yin], then adapted to this hardware; the sources
live in the `Refs:` comment at the top of each file.

- **CPU frequency** - `auto-cpufreq` uses `powersave` with EPP `power` on battery, capped at 3 GHz
  with turbo off; on AC it uses `performance` and lets the automatic policy handle turbo. I do not
  set a minimum frequency, leaving room to downclock when idle.
- **Display** - on battery, brightness drops to 60% and refresh rate switches to 60 Hz; on AC it
  returns to 100% and 144 Hz. A udev rule listens for power events.
- **Thermals and audio** - `thermald` handles thermal management, and the audio codec enables power
  saving at module load.
- **Device power** - `powertop --auto-tune` at boot, plus USB autosuspend and PCIe runtime power
  management.
- **Peripherals** - I disable the Bluetooth radio I do not use; the Logitech 2.4 GHz receiver is an
  exception so the first mouse move after wake does not stutter.
- **Other system settings** - Wi-Fi power saving, zram and Btrfs compression are listed under
  [Hardware and System Policies](#hardware-and-system-policies).

These policies live in a few modules, so they are easy to locate and change when something feels
wrong. They fit this machine only; other hardware will need its own validation.

## Readability

Small fonts and dense interfaces tire my eyes quickly. On a laptop screen, the most valuable space
should go to whatever I am reading.

### A Lean Interface

I dislike decorative animation such as cursor trails, and I dislike frosted glass. They interfere
with reading commands and text, and they get tiring over time. I want a desktop that stays clean and
legible in long sessions.

With that in mind:

- **No persistent bar.** I used to run Waybar, but on this screen a large one takes space and a
  small one is hard to read. I tried hiding it, found that opening Btop on demand fits me better,
  and dropped the bar entirely in the current setup.
- **Larger text.** The terminal and input method use Maple Mono NF CN, whose size comes from the
  shared value `16` in [system/theme.nix](system/theme.nix); Neovim in the terminal follows the
  terminal font.
- **Fullscreen browsing.** My browser is Zen Browser Beta mainly for its fullscreen mode, which
  tucks the interface away and gives the page more room.
- **A soft dark theme.** I use a green-grey palette called "Koru Fern", pairing a dark background
  with fern green and soft yellow accents for long reading sessions.
- **A font that handles both scripts.** Maple Mono NF CN also typesets mixed Chinese and Latin in the
  terminal, so code and text look consistent.

The goal is simple: **make reading easier**. Font sizes, colors and density all stay adjustable.

## Clean and Traceable

My version of being fussy is simple: I do not like opaque systems. I want to know why a piece of
software was installed, where a setting comes from, and which file to change when I no longer want
it. NixOS's declarative configuration fits that well, and it let me turn daily maintenance into a
clear process.

After using NixOS I realized the distributions I had used before were not that different from each
other, and none of them solved this problem. What I could not stand was leftovers: when a system
build went wrong, my answer used to be to wipe and reinstall. Distributions like Ubuntu also spread
configuration around - some of it through commands, some through config files - and command-based
changes leave no good record, are hard to reproduce, and sometimes I could not even remember whether
I had done them. With NixOS everything is centralized: I write configuration, and a query tells me
what changed; to remove software I drop its entry and rebuild; and a broken build rolls back
cleanly. It is the most elegant system I have used.

Concretely, this configuration:

- **Defines shared settings in one place.** Colors, fonts and sizes come from the shared theme; which
  user modules are on is decided by one switchboard.
- **States what is managed.** System packages and managed config are declared by the repository.
  Remove the declaration, re-apply, and the install or config follows; runtime data still belongs to
  the program or to me.
- **Surfaces problems early.** User modules and the switchboard are validated in both directions, so
  missing, extra or unsatisfied entries fail at evaluation; `nix flake check` also runs format, lint
  and dead-code checks.
- **Keeps a way back.** System, user and development-tool generations are retained, so a bad change
  can return to a known state; a scheduled GC clears old generations and unreferenced build output.
- **Draws the boundary.** What Nix manages and what is your runtime data is listed under
  [What Rollback Covers](#what-rollback-covers), so rollback is not mistaken for a full restore.

Organized this way, maintenance is calmer: when something breaks I know where to look, and I know
what a change will touch.

## Architecture

To let the configuration grow with daily needs, I keep the host, system, user layer and development
tools separate. When deciding where a setting belongs, I first ask what it manages, then through
which entry point it takes effect.

### Directory Layout

```text
.
├── flake.nix                  # inputs, system and user outputs, checks
├── flake.lock                 # system and user dependency lock
├── hosts/
│   ├── inventory.nix          # host names and architectures
│   └── koru/                  # this machine: hardware, boot, power, accounts
├── system/                    # explicitly imported system modules, shared theme
├── home/
│   ├── default.nix            # Home Manager entry and module validation
│   ├── modules-enables.nix    # user software switchboard (single inventory)
│   ├── <software>.nix         # single-software modules
│   ├── niri/                  # desktop helper modules and keybinding data
│   └── dotfiles/              # non-Nix files referenced by modules
├── profile/                   # independently locked development toolchain
├── lib/                       # module discovery, dependency rules, packaging
├── scripts/                   # build, maintenance, module editing, proxy logic
├── completions/               # command-line completion
├── assets/                    # logos and other static assets
├── tests/                     # CLI, module, proxy and toolchain verification
└── .github/workflows/         # continuous integration
```

### Layer Responsibilities

`hosts/` holds machine-specific settings and `system/` manages system services; `nixos-rebuild`
applies both. `home/` manages the user layer, which is applied with the system and can also be
switched on its own. Development tools live in `profile/` and update through their own Nix profile.

Desktop settings split along the same boundary: Niri's system session support is in `system/`, while
layout, keybindings and user-side helper services are in `home/`.

The configuration falls into four layers by activation entry point:

| Layer | What it manages | Entry point |
| --- | --- | --- |
| Host | UUIDs, filesystems, boot parameters, devices, power and accounts | [hosts/koru/default.nix](hosts/koru/default.nix) |
| System | Desktop session, network, audio, input-method backend, Nix and system services | [system/default.nix](system/default.nix) |
| User | Software install, desktop settings, shell, application config and user services | [home/default.nix](home/default.nix) |
| Development tools | Independently installed compilers, runtimes and commands | [profile/default.nix](profile/default.nix) |

[home/modules-enables.nix](home/modules-enables.nix) is the user-layer switchboard: one boolean per
module, `true` to install and `false` to keep the source but skip loading it. It is validated against
the module files directly under `home/`, and any mismatch fails evaluation. Helper modules in nested
directories are imported by their owning module.

### Flake Outputs

| Output | Purpose |
| --- | --- |
| `nixosConfigurations.koru` | Full NixOS system with embedded Home Manager |
| `homeConfigurations.koru` | Standalone user configuration |
| `homeConfigurations.all` | Forces every user module on, for checks |
| `devShells.x86_64-linux.default` | Nix formatting and static-check tools |
| `checks.x86_64-linux.*` | Format, lint, dead-code and proxy-VM checks |
| `profile/` -> `packages.x86_64-linux.dev-tools` | Independent development toolset |

### What Rollback Covers

| Content | Managed by |
| --- | --- |
| System packages; Flake inputs such as Home Manager, Zen Browser and OpenCode | root `flake.lock` |
| Development tools and ROS overlay | `profile/flake.lock` |
| Codex CLI | Installed / updated from npm `latest` into a private prefix on Home Manager activation |
| Remaining Neovim plugins and user config | Maintained by me |
| Proxy subscriptions, caches, tool credentials, project dependencies | Their own local files or project config |

I keep this boundary in mind: a Nix generation rollback restores the build output and managed config
of that layer, while npm-installed software, user runtime data and the Git working tree are managed
separately. That way I know in advance what a rollback will and will not restore.

## Theme

Shared colors, fonts, sizes and cursor settings live in [system/theme.nix](system/theme.nix) as pure
data, passed to both layers through `specialArgs` / `extraSpecialArgs`. Kitty, GTK, the cursor, the
TTY, Neovim themes and menus read what they need, giving one clear entry point when adjusting the
theme.

"Koru Fern" uses a dark green-grey background with fern green and soft yellow for focus and sparing
accents.

| Role | Color |
| --- | --- |
| Primary background `bg` | `#171E1A` |
| Secondary background `bg-alt` | `#222D26` |
| Foreground `fg` | `#D2DCD0` |
| Primary accent `accent` | `#8FBF88` |
| Yellow accent `accent-yellow` | `#E6D87A` |
| Selection background `accent-bg` | `#334936` |
| Inactive border `border` | `#425347` |

Font sizes are defined here too: `16` for the terminal and input method, `11` for GTK widgets and
`12` for small interfaces such as menus. Each component keeps its own unit, and I hold the overall
look with the shared values, then fine-tune by eye.

The header logo is [assets/fastfetch/koru-logo.png](assets/fastfetch/koru-logo.png), the same
transparent PNG Fastfetch uses; see [assets/fastfetch/README.md](assets/fastfetch/README.md) for its
source.

## Components

| Area | What I use |
| --- | --- |
| Window manager | [Niri] (Wayland, scrolling tiling) |
| Terminal | [Kitty] + Zsh with [Fzf], [Fd], [Ripgrep] and [Zoxide]; [Bat] and [Eza] for previews and listings |
| Editor | [Neovim] via Nix; `EDITOR` / `VISUAL` set and `nvim/lua/p10k.lua` generated from the shared theme |
| AI tools | Codex CLI and OpenCode, each self-managed and themed to match |
| Browser | Zen Browser Beta, mainly for its fullscreen mode |
| Documents | [Zathura] (PDF), [LibreOffice] (with a `topdf` helper), [Draw.io], [imv], [Satty] for screenshots |
| Input method | [Fcitx5] + [Rime]; tapping either Shift commits the raw Latin code and toggles ASCII |
| System monitor | [Btop] |
| Theme | "Koru Fern", a green-grey dark palette defined in `system/theme.nix` |
| Fonts | Maple Mono NF CN, size `16` for terminal and input method |
| Power | `auto-cpufreq`, `thermald`, `powertop --auto-tune`, UPower and USB exceptions |
| Memory | zram, reclaim parameters and `systemd-oomd` |
| Storage | Btrfs subvolumes with compression |
| Network | NetworkManager, static DNS, Wi-Fi power saving and pinned GitHub hosts |
| Proxy | mihomo, driven by the `koru proxy` commands |
| Recording | GPU Screen Recorder with a KMS permission wrapper |
| Utilities | `koru` CLI for system / home / profile management, proxy control and a small auto-clicker |
| Development tools | Rust, C/C++, Java, Node.js, Python, MPI, ROS 2, Typst and Just, in `profile/` |

## Hardware and System Policies

The main hardware and system policies are collected below, next to their source. They are choices
made for this laptop; if you borrow them, adapt to your own hardware and habits.

| Scope | Current policy | Source |
| --- | --- | --- |
| Display | 60% brightness on battery, 100% on AC; picks the closest 60 / 144 Hz mode among the available 1920x1080 modes | [hosts/koru/display-power.nix](hosts/koru/display-power.nix) |
| Idle display | Dim to at most 10% after 5 minutes, turn off after 10; restore the saved brightness on activity, no automatic suspend | [home/niri/idle-dimming.nix](home/niri/idle-dimming.nix) |
| Power | CPU, thermal management, UPower, Powertop and USB exceptions | [hosts/koru/power-management.nix](hosts/koru/power-management.nix) |
| Graphics | Intel rendering, video acceleration and GuC parameters | [hosts/koru/intel-graphics.nix](hosts/koru/intel-graphics.nix) |
| Bluetooth | Service off and radio blocked | [hosts/koru/bluetooth.nix](hosts/koru/bluetooth.nix) |
| Filesystem | Btrfs compression, access time and TRIM policy | [hosts/koru/btrfs-mounts.nix](hosts/koru/btrfs-mounts.nix) |
| Memory | zram, reclaim parameters and `systemd-oomd` | [system/memory-zram.nix](system/memory-zram.nix) |
| Network | NetworkManager, static DNS, Wi-Fi power saving and pinned GitHub hosts | [system/network-manager.nix](system/network-manager.nix), [system/github-hosts.nix](system/github-hosts.nix) |
| Recording | GPU Screen Recorder with a KMS permission wrapper | [system/gpu-screen-recorder.nix](system/gpu-screen-recorder.nix) |
| Nix | China mirrors with an official-cache fallback, build parallelism and a low-disk GC threshold | [system/nix-daemon.nix](system/nix-daemon.nix) |
| Logs and cleanup | Journal size limits, daily GC and manual dependency updates | [system/journal-limits.nix](system/journal-limits.nix), [system/nix-garbage-collection.nix](system/nix-garbage-collection.nix) |

The display policy targets the built-in panel and is not a general multi-monitor setup. Idle dimming
keeps a lower brightness if one was already set, and boot or power events re-apply the matching
policy.

## Daily Workflow

This machine covers coursework, daily development and ROBOCON work. I mostly use Python and Rust,
spend my time in the terminal, browser and editor, and open other tools as needed.

| Task | How |
| --- | --- |
| Terminal and navigation | [Kitty] + Zsh with [Fzf], [Fd], [Ripgrep] and [Zoxide] for fuzzy selection, finding files, searching and jumping; [Bat] and [Eza] for readable previews and listings |
| Editing and AI | [Neovim] installed through Nix, with `EDITOR` / `VISUAL` set and `nvim/lua/p10k.lua` generated to match the shared theme; other Neovim config and plugins are mine. Codex CLI and OpenCode are independent, themed to "Koru Fern", and own their credentials and session data |
| Documents and images | Zen Browser for the web, [Zathura] for PDFs, [LibreOffice] for office files, [Draw.io] for diagrams and [imv] for images. Enabling LibreOffice also provides `topdf`, which converts through a temporary profile to avoid clashing with an open office suite |
| Input method | [Fcitx5] + [Rime]. Tapping Shift commits the raw Latin code and switches to ASCII, which is handy between Chinese and code; framework-level switching is handled separately |
| Development tools | Rust, C/C++, Java, Node.js, Python, MPI, ROS 2, Typst and Just live in the independent profile, so updates do not rebuild the system; see [profile/README.md](profile/README.md) |

## Maintenance and Rollback

Daily maintenance goes through the repository's `koru` CLI. Changes take a shared lock to avoid
concurrent runs, and the operation log is written to
`${XDG_STATE_HOME:-$HOME/.local/state}/koru/operation.*.log`, so a failure can be traced from there.

| Scope | Check | Apply | History |
| --- | --- | --- | --- |
| System with embedded user config | `koru system check` | `koru system build` | `koru system list` |
| Standalone user config | `koru home check` | `koru home build` | `koru home list` |
| Development tools | `koru profile check` | `koru profile build` | `koru profile list` |

I usually run the matching `check` first to confirm the build succeeds, then `build` to apply it.
Here `check` does a real build but neither activates nor creates a `result` link; it is not the same
as `nix flake check`, which runs the full set of flake checks.

To roll back, list the retained generations and pass an ID:

```sh
koru system rollback --generation <ID>
koru home rollback --generation <ID>
koru profile rollback --generation <ID>
```

Replace `<ID>` with a real generation number from the list. A system rollback also updates the
default boot generation. The scheduled GC runs daily at `03:15` and clears generations older than
seven days, so keep an explicit GC root for anything you need long-term.

User modules can also be inspected and changed from the CLI:

```sh
koru home modules
koru home enable <module>
koru home disable <module>
koru home validate
```

After changing a switch, run `koru home build` or `koru system build` to apply it. Commands for proxy
management and store cleanup are listed by `koru --help`.

Adding a user module means adding both `home/<software>.nix` and a matching switch in
`modules-enables.nix`, and registering dependencies when needed, or evaluation fails. A system
module is imported explicitly in `system/default.nix`.

## Deployment and Migration

This configuration grew around my main laptop, so the repository has no generic disk layout or
from-scratch install flow. To borrow from it, start with the piece you need: power policy, theme,
user-module management and the independent development profile each have their own entry point.

> :red_circle: **Do not deploy this flake directly on your machine.** It carries this laptop's
> hardware configuration and reads a local password file, so it will not fit your hardware. Use it
> as a reference and build your own.

To migrate the whole configuration, check these entry points against the target machine:

| Content | Location and notes |
| --- | --- |
| Username, output construction | `username` and related definitions in [flake.nix](flake.nix) |
| Host name and architecture | [hosts/inventory.nix](hosts/inventory.nix) and the matching `hosts/<name>/` directory |
| Hardware detection and filesystems | A `hardware-configuration.nix` generated for the target, with UUIDs and mount points checked |
| Boot and device policy | `hosts/koru/boot.nix`, `intel-graphics.nix`, `btrfs-mounts.nix` |
| Display and power | `display-power.nix`, `power-management.nix`, adjusted for the target hardware |
| Accounts and login | `user-account.nix` currently uses a local password file, an immutable user and tty1 autologin |
| Network and SSH | SSH password login is allowed, root login denied, TCP 22 and 8080 open |
| Repository path and management command | Defaults to `~/.config/nixos`; `koru` operations currently target the `koru` output |
| Software selection | [home/modules-enables.nix](home/modules-enables.nix) |

The account configuration reads a plaintext password from the local `hosts/koru/password` file -
a personal choice for this single-user machine that you should replace. Proxy subscriptions and tool
credentials use separate local files and are not part of the repository.

System dependencies are pinned by the root `flake.lock` and development tools by
`profile/flake.lock`; a normal build will not update the lock files.

## Checks and CI

To catch problems early while the configuration is maintained, the [CI workflow](.github/workflows/check.yml)
runs:

| Check | Coverage |
| --- | --- |
| Nix static checks | nixfmt, statix, deadnix |
| Configuration evaluation | System output, standalone user output and every user module |
| Shell and CLI | ShellCheck, command contracts, module editing, proxy and profile tests |
| Proxy VM | Real sudo authorization, systemd credentials, TUN start/stop, refresh and failure recovery, against a local HTTP fixture |
| Development tools | Compile, link and run samples across Rust, C/C++, Java, Node, Python tools, MPI, ROS, Typst and Just |
| Full build | The NixOS system closure and the standalone Home Manager activation package |

These checks catch source, evaluation and build problems. The desktop experience itself still needs
confirming on the machine - switching physical displays, input-method keys and real proxy
subscriptions - and CI never activates the laptop configuration.

## FAQ

### I disabled a user module, but the software is still there. Why?

It may be installed by the system layer or another module's dependency. A user-module switch only
controls that Home Manager module; it does not delete user data or undo installs from other layers.

### Why does `koru home build` alone not take effect?

First check which layer the change belongs to. System services, hardware config, group membership
and the desktop backend need a system switch; user application settings are Home Manager's. A running
program may also need a reload, restart or re-login.

### After a rollback, why did the source and some software versions stay the same?

Rollback restores the retained profile generation and does not touch the Git working tree; software
installed from npm and data you maintain yourself do not move with a generation. See
[What Rollback Covers](#what-rollback-covers).

### Why can I not find an earlier generation?

Old generations may have been cleared by the scheduled GC. Check the matching `list` output and pick
an ID that still exists; set an explicit GC root for a development environment you need long-term.

### Where should I start reading?

Start with what you care about: power under [Hardware and System Policies](#hardware-and-system-policies)
and `hosts/koru/`, reading comfort under [Theme](#theme), and module organization under
[Architecture](#architecture). I try to keep the reasoning in the documentation and source comments
so you can judge what fits you.

## References

Projects that inspired this configuration:

- [nyx] - power-management and module layout ideas.
- [Misterio77] - a clean, well-structured NixOS and Home Manager flake.
- [ryan4yin] - deployment and modularity patterns, and a good introduction to NixOS with flakes.

[Niri]: https://github.com/YaLTeR/niri
[Kitty]: https://github.com/kovidgoyal/kitty
[Neovim]: https://github.com/neovim/neovim
[Fcitx5]: https://github.com/fcitx/fcitx5
[Rime]: https://rime.im/
[Zathura]: https://pwmt.org/projects/zathura/
[LibreOffice]: https://www.libreoffice.org/
[Draw.io]: https://www.drawio.com/
[imv]: https://sr.ht/~exec64/imv/
[Satty]: https://github.com/gabm/satty
[Btop]: https://github.com/aristocratos/btop
[Fzf]: https://github.com/junegunn/fzf
[Fd]: https://github.com/sharkdp/fd
[Ripgrep]: https://github.com/BurntSushi/ripgrep
[Zoxide]: https://github.com/ajeetdsouza/zoxide
[Bat]: https://github.com/sharkdp/bat
[Eza]: https://github.com/eza-community/eza

[NixOS Wiki FAQ]: https://wiki.nixos.org/wiki/FAQ
[nyx]: https://github.com/notashelf/nyx
[Misterio77]: https://github.com/Misterio77/nix-config
[ryan4yin]: https://github.com/ryan4yin/nix-config
