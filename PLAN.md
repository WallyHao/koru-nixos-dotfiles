# Koru Improvement Plan

Status: implementation reference. Activation, dependency updates, garbage
collection, and runtime configuration changes remain explicit user actions.

## 1. Goals and boundaries

Give Koru a recognizable fern-green dark identity, improve daily maintenance,
make proxy operations discoverable, preserve typed English when switching input
modes, and keep battery life and productive work as the primary design goals.

All maintained configuration, comments, documentation, command names, help text,
and diagnostic messages must use English. User content and upstream node names
may contain other languages and must remain intact.

Preserve the existing host identity, hardware configuration, state versions,
dependency pins, and power policy during these improvements. Existing uncommitted
changes are the baseline; do not overwrite them. Implement the work in separate,
reviewable changes.

## 2. Repository findings

| Area | Existing implementation | Planned approach |
| --- | --- | --- |
| Theme | `system/theme.nix`, shared through flake arguments | Replace the warm-apricot palette in place |
| System output | `nixosConfigurations.koru`, with embedded Home Manager | Expose explicit build, test, switch, and rollback recipes |
| Home outputs | `homeConfigurations.koru` and evaluation-only `all` | Expose user-only operations; never activate `all` |
| Software selection | `home/module-selection.nix`, with boolean and inventory checks | Keep this Nix file as the sole switchboard |
| Task runner | `home/just.nix` installs Just; no repository Justfile | Add a capitalized `Justfile` with descriptive recipes |
| Validation | nixfmt, statix, deadnix, and CI evaluation | Reuse and extend the existing checks |
| Proxy | Bash embedded in `system/mihomo.nix`; on-demand Mihomo TUN | Separate CLI implementation, completion, and service wiring |
| Completion | Zsh and fzf-tab already configured | Supply `_proxyctl`; fzf-tab then displays its candidates |
| Input method | Fcitx5-Rime with rime-ice; customization in `home/fcitx5.nix` | Configure raw-input commit at both relevant layers |
| Power | auto-cpufreq, thermald, display profiles, AC-only scheduled GC | Preserve these owners; avoid competing power managers |

Important constraints already present:

- A system switch also applies the embedded Home Manager configuration. A home
  switch cannot install system input-method services or apply system theme consumers.
- Disabling a module removes its configuration contribution, but another module
  or the embedded system profile may still provide the same package.
- Existing GC runs at 03:15 on AC with a seven-day retention policy. Rollback
  availability must be considered before expanding cleanup commands.
- `proxyctl refresh` currently stops the active proxy before probing; this is a
  connectivity interruption that must become explicit in the CLI.
- The actual local Fcitx5 hotkey state is not established by the repository alone.
  Confirm it during implementation before claiming the precise runtime cause.

## 3. Theme: Koru Fern

Use deep green-charcoal surfaces, soft neutral text, and restrained fern accents.
Avoid pure black surfaces, pure white body text, neon greens, and large saturated
panels. This is a visual comfort preference, not a medical eye-protection claim.

### Semantic palette

Keep the existing attribute names to minimize churn across consumers.

| Token | Proposed value | Intended use |
| --- | --- | --- |
| `bg` | `#171E1A` | Main background |
| `bg-alt` | `#222D26` | Raised surfaces and panels |
| `black` | `#121813` | Deepest surface and text on bright accents |
| `fg` | `#D2DCD0` | Main text |
| `fg-bright` | `#E1E8DB` | Emphasized text |
| `muted` | `#A5B3A2` | Secondary readable text |
| `muted-alt` | `#788A78` | Subdued decoration; validate before text use |
| `accent` | `#8FBF88` | Fern green, focused borders, titles |
| `accent-deep` | `#527B59` | Graph starts and decoration |
| `accent-bright` | `#B4D6A2` | Sparse highlights |
| `accent-bg` | `#334936` | Selection background |
| `cursor` | `#DEE7D5` | Cursor and selection text |
| `border` | `#425347` | Inactive borders |
| `urgent` | `#D39B79` | Warnings and attention |

### ANSI palette

Retain recognizable terminal color roles so errors, warnings, diffs, and syntax
remain distinguishable. Green is the identity color, not the only signal.

| Color | Normal | Bright |
| --- | --- | --- |
| Black | `#222D26` | `#526457` |
| Red | `#CC8F88` | `#DDA39A` |
| Green | `#8FBF88` | `#B4D6A2` |
| Yellow | `#C4B783` | `#D8CCA0` |
| Blue | `#8EAAB8` | `#ACC3CE` |
| Magenta | `#B39BB5` | `#CAB5CA` |
| Cyan | `#88B8AB` | `#A6D0C2` |
| White | `#D2DCD0` | `#E1E8DB` |

Start the console palette from these values with console black mapped to `bg`;
verify it separately on a real TTY. Preserve the current font and sizes initially.

### Integration and acceptance

1. Update `system/theme.nix` and the theme-specific names and comments in its
   consumers. Audit Alacritty, Niri, GTK, Neovim, bat, btop, Fcitx5, fzf, wmenu,
   Zsh/p10k, cursor generation, and the console.
2. Rename the generated cursor consistently to `Bibata-Modern-Koru`; distinguish
   upstream asset paths from the installed theme name when updating its builder.
3. Make the Fcitx5 panel border subdued green. Reserve warning colors for warnings;
   use a dark green selection surface with readable foreground. The current
   highlight PNG is generated but not referenced by the active highlight section;
   either wire it deliberately or remove that unused generated asset.
4. Keep opaque terminal backgrounds and minimal effects as the default. Do not
   add wallpaper daemons, blur, animated decorations, or continuous rendering.
5. Calculate contrast for actual foreground/background pairs, including selection
   and GTK accent buttons. Target at least 4.5:1 for ordinary text and 3:1 for
   essential UI boundaries. Do not assume low-emphasis colors pass these targets.
6. Review normal/error terminal output, editor diffs, disabled GTK controls,
   candidate selection, and focused/unfocused windows at the existing battery
   brightness. Check GTK/libadwaita and Qt coverage honestly; shared tokens do not
   guarantee that every application honors custom styling.

## 4. Justfile and maintenance workflow

Keep `Justfile` as an orchestration layer. Place substantial logic in dedicated
scripts. Default `just` should show the documented recipe list. Use English
hyphenated names and comments that appear in `just --list`.

Recipes run from the repository directory. Default the host to `koru`, validate
host names against `hosts/inventory.nix`, quote arguments, and use strict shell
error handling. Use pinned tools exposed through a small development shell or
flake packages so checks still work when optional home tooling is disabled.

### Recipe contract

| Recipe | Behavior |
| --- | --- |
| `help` | List commands and short descriptions |
| `system-hosts-list` | List available NixOS host outputs and architectures |
| `system-information` | Show running host, OS/kernel, active system path, and power source |
| `system-generations-list` | List system generations, marking current where available |
| `home-generations-list` | List standalone Home Manager generations |
| `system-configuration-build host="koru"` | Build the selected system without activation |
| `system-configuration-test host="koru"` | Activate temporarily using the rebuild test action |
| `system-configuration-switch host="koru"` | Apply the system and embedded Home Manager |
| `system-configuration-boot host="koru"` | Prepare the configuration for the next boot |
| `home-configuration-build host="koru"` | Build the standalone home profile without activation |
| `home-configuration-switch host="koru"` | Apply the standalone home profile without sudo |
| `system-generation-rollback` | Activate the preceding system generation |
| `home-generation-activate generation` | Resolve a listed standalone generation and run its activation |
| `configuration-format` | Format maintained Nix sources; explicitly mutating |
| `configuration-format-check` | Run formatting checks without rewriting files |
| `configuration-lint-check` | Run statix with `statix.toml` |
| `configuration-dead-code-check` | Run deadnix in fail-only mode |
| `configuration-evaluate host="koru"` | Force system and standalone home derivation evaluation |
| `configuration-evaluate-all-home-modules` | Evaluate the existing `all` home output |
| `configuration-check` | Run flake checks plus explicit home-output evaluation |
| `garbage-collection-preview` | Report reclaimable store paths and relevant generations |
| `garbage-collection-run` | Collect unreachable paths without first deleting generations |
| `system-generations-prune age="7d"` | Explicitly prune old system generations under the retention policy |
| `home-generations-prune age="7d"` | Explicitly expire old standalone home generations |
| `home-modules-list` | Show configured module flags |
| `home-module-enable name` | Validate and enable one flag; do not activate |
| `home-module-disable name` | Validate and disable one flag; do not activate |
| `home-modules-validate` | Validate switchboard structure, inventory, and selected evaluation |

Use these existing entry points as the foundation, verifying flags against the
versions pinned by `flake.lock` during implementation:

```sh
nixos-rebuild build --flake .#koru
sudo nixos-rebuild switch --flake .#koru
home-manager build --flake .#koru
home-manager switch --flake .#koru
nix flake check --no-update-lock-file --print-build-logs
nix eval --no-update-lock-file --raw .#nixosConfigurations.koru.config.system.build.toplevel.drvPath
nix eval --no-update-lock-file --raw .#homeConfigurations.koru.activationPackage.drvPath
nix eval --no-update-lock-file --raw .#homeConfigurations.all.activationPackage.drvPath
```

Normal checks and rebuild recipes must not implicitly update `flake.lock`.
Distinguish syntax/static checks, evaluation, builds, activation, and desktop
testing in both help text and documentation. Evaluation does not prove that all
packages build or that desktop interactions work.

Cleanup must default to preserving generations. Preview is an estimate because
roots can change before collection. Prune recipes must explain reduced rollback
coverage, retain the current generation, validate age arguments, and use a
separate explicit confirmation/force option. Keep expensive maintenance AC-only
by default with an explicit override for manual use. Do not silently increase the
existing scheduled retention aggressiveness or run store optimization with GC.

Document that `test` can still restart services, and that generation rollback
does not restore source files. Embedded and standalone home profiles have distinct
lifecycles; a standalone switch may leave packages provided by the last system
generation until the next system switch.

Install Just's Zsh completion from the pinned binary. Supplement module-name
arguments with cached/local switchboard names, without activation or network
access on Tab. Existing shell rebuild aliases should delegate to recipes once
the workflow is stable. Do not auto-stage files: explain Git-flake visibility for
new source paths and let the user review explicit intent-to-add operations.

## 5. Declarative software enable/disable

Retain `home/module-selection.nix`. It already meets the single-file requirement
and is consumed by both system-embedded and standalone Home Manager. Introducing
a JSON mirror would create competing sources of truth without a clear benefit.

Keep its restricted data shape:

```nix
{
  enable = {
    alacritty = true;
    libreoffice = false;
    # Other existing module flags remain present.
  };
}
```

The excerpt illustrates syntax only; do not adopt its example values as a
requested software change.

Implement `scripts/home-modules` as a small transactional editor for this
restricted boolean table. Prefer a syntax-aware edit; a narrowly defined parser
may support the current literal format but must refuse unsupported expressions,
duplicate assignments, or ambiguous matches. Do not use unrestricted `sed`
replacement or evaluate arbitrary text as shell commands.

Transaction requirements:

1. Lock against concurrent edits and read the original bytes and content hash.
2. Validate the requested name against discovered modules and existing flags.
3. Make an idempotent edit to a temporary candidate, preserving other settings
   and comments. Report `Already enabled` or `Already disabled` when appropriate.
4. Format and validate the candidate, including boolean/inventory assertions and
   the selected home output. Evaluate a temporary source copy with the candidate
   at its canonical path, or expose a dedicated validation entry point. Do not
   temporarily replace the live switchboard merely to evaluate it.
5. Confirm the source hash is unchanged, then atomically replace that one file.
   Leave the original untouched on validation failure and clean up temporary data.
6. Print the changed flag and the explicit apply command. Never rebuild, update
   dependencies, or stage Git changes as a side effect of enable/disable.

Audit dependency edges before claiming every switch is independently usable:
Niri shortcuts reference applications; tty login depends on a working compositor;
shell configuration refers to fzf/fd/bat/eza/zoxide; optional modules can have
additional couplings. Gate dependent configuration where sensible and add clear
assertions for invalid combinations. Do not silently re-enable a disabled module.

Keep dependencies/validation helpers under `lib/` or nested directories; adding
helper `.nix` files directly under `home/` changes the discovery inventory.
Disabling a module must not delete personal data or promise that all transitively
installed packages disappear. Critical session modules should carry explanatory
warnings, while still allowing deliberate valid configurations.

Acceptance: enable, disable, repeat, unknown key, malformed value, concurrent
edit, validation failure, and dependency failure all behave predictably. Both
home and embedded outputs consume the same selected flags.

## 6. Proxy CLI, completion, and measurements

### Structure and presentation

Move CLI logic into `scripts/proxyctl.sh`, package it through
`pkgs.writeShellApplication`, and keep service/credential wiring in
`system/mihomo.nix`. Store `_proxyctl` under `completions/` and install it in the
package's `share/zsh/site-functions`. Verify it is visible in Zsh's `fpath` before
completion initialization. Keep injected paths explicit and runtime dependencies
pinned; do not rely on incidental user PATH entries.

Retain `start`, `status`, `shutdown`, `refresh`, and `help`. Add `nodes`,
`start --node NAME`, `status --json`, `status --latency`, `status --traffic`,
`status --speed-test`, and `--color auto|always|never`. `status` is the canonical
spelling; a `stutas` typo should receive a useful suggestion. Internal privileged
subcommands must not appear in public help/completion and must validate privileges
and arguments rather than treating hidden names as a security boundary.

Use shared fern colors for headings, success, warnings, and errors. Honor
`NO_COLOR`, non-TTY output, and `TERM=dumb`; retain text labels and ASCII fallbacks.
Keep JSON output uncolored and parseable, diagnostics on stderr, and ordinary
results on stdout. Escape control characters in upstream node names before
display while preserving their exact raw values for API operations.

Illustrative output, not measured data:

```text
Koru Proxy
  Service       active
  Controller    reachable
  Mode          rule (all traffic routed to PROXY)
  Node          US Fern 01
  TUN           active
  Node cache    12 usable nodes, refreshed 18 minutes ago
  Latency       not measured (use --latency)
```

Report partial states honestly: a service can be active while its controller,
selected node, or TUN interface is unavailable. Avoid the current interface-name
substring heuristic; inspect actual configured/runtime interface information.
Set connection and overall timeouts on every API request. Define exit codes:
`0` for a successful query/action (including a reported inactive service), `1`
for operational failure or a requested failed measurement, `2` for invalid usage,
and `130` for interrupted interactive work. JSON should include explicit state,
measurement errors, units, and timestamps rather than using zero for missing data.

Refresh output should report fetch, parse, probe, reachable/failed totals, cache
write, and service outcome. Preserve the previous valid cache on failure and use
atomic writes. State that refreshing interrupts an active TUN; add an explicit
restore option if restoring the prior service/node can be tested reliably. Do
not silently alter the existing US-first ranking policy in this presentation work.
Remove the current subscription URL from download-error messages because it can
contain credentials. Never print bearer secrets or raw credential-bearing curl
errors. Keep runtime data outside the Nix store with restrictive permissions.

### Completion

Implement descriptive Zsh `_arguments`/`_describe` completion for all public
commands and flags, plus node names from the existing local cache. Do not run
refresh, sudo, controller probes, or downloads on Tab. Handle spaces, Unicode,
and shell metacharacters in names as data. Missing/stale caches should yield a
helpful description without making completion fail.

fzf is a selector, not a command-discovery database. fzf-tab consumes Zsh's
completion candidates. Verify both plain Zsh completion and the existing
fzf-tab integration in a fresh shell; ensure plugin ordering does not override
the completion widgets. Retain an interactive fzf node picker with aligned
latency columns, clear units, and an English header.

### Measurement semantics

| Invocation | Measurement | Resource policy |
| --- | --- | --- |
| `proxyctl status` | Local service/controller/cache state | No external probe; bounded local calls |
| `proxyctl status --latency` | Current node HTTP probe latency via Mihomo delay API | A few bounded samples, no full-node refresh |
| `proxyctl status --traffic` | Current upload/download traffic rate | Bounded sample of the traffic stream; no generated traffic |
| `proxyctl status --speed-test` | Actual download goodput through the current proxy | Explicit user request; bounded bytes and duration |

Use URL-encoded node names and query parameters for
`/proxies/{name}/delay`. Report the target URL, sample count, failures, and measured
latency; this is not ICMP RTT and not bandwidth. Label existing node-cache latency
with its age rather than presenting it as a fresh measurement.

Mihomo's `/traffic` stream reports existing traffic rates; it is not a synthetic
speed test. A download test should use an explicitly configured HTTPS endpoint
with known bounded content, force the request through `127.0.0.1:7890`, discard
the body, disable retries, and enforce both a byte cap and a time cap (initial
budget: 10 MiB and 15 seconds). Enforce the byte limit even if a server ignores
Range. Report bytes actually transferred, duration, MiB/s and Mbit/s, and whether
the sample was capped. Short samples are approximate download goodput, not a
claim about total link capacity. Do not add automatic upload tests, persistent
polling, public-IP lookups, or background benchmarks.

If the service is off, measurement commands explain why they cannot run; they
must not start it, change nodes, or fall back to a direct connection. Surface
network failures separately from proxy-state failures.

Acceptance: active/inactive/failed service, missing secret/cache, controller
timeout, malformed responses, cancelled picker, unusual node names, plain/JSON
output, color suppression, completion, and successful/failed/capped measurements.
Use mocked commands/API responses for repeatable CLI tests; reserve real network
tests for an explicit manual implementation check.

## 7. Preserve raw English when pressing Shift

Desired example: with Chinese mode active, type `hello`, then tap Shift. The
application receives `hello`, the composition ends, and following input is English.
Do not commit the first Chinese candidate or discard the typed letters.

Two mechanisms need coverage. Rime can switch its internal ASCII mode, while
Fcitx5 can deactivate Rime and switch to `keyboard-us`. Upstream Fcitx5-Rime exposes
`SwitchInputMethodBehavior`, whose current upstream default commits the preview;
the installed revision and actual hotkeys must still be checked before diagnosis.

Extend the existing `default.custom.yaml` patch in `home/fcitx5.nix`, preserving
the rime-ice include and page size:

```yaml
patch:
  __include: rime_ice_suggestion:/
  menu/page_size: 7
  ascii_composer/switch_key/Shift_L: commit_code
  ascii_composer/switch_key/Shift_R: commit_code
```

Also manage `fcitx5/conf/rime.conf` with:

```ini
SwitchInputMethodBehavior=CommitRawInput
```

Confirm these options against the pinned packages. Prefer letting a bare Shift
reach Rime for the internal toggle; keep a distinct explicit framework shortcut
such as Ctrl+Space. Inspect and manage only the necessary Fcitx5 hotkey fields so
framework toggles do not race Rime's Shift handling. If a schema overrides the
global setting, patch the active schema and verify the deployed merged result.

Apply through Home Manager, then redeploy Rime and reload/restart Fcitx5 at a
suitable time. Do not modify generated Rime build files, delete user dictionaries,
or replace learned data. Preserve unrelated local preferences when adopting the
managed `rime.conf`; avoid blindly forcing over an existing file.

Manual acceptance matrix:

- Left and right Shift preserve an existing raw Latin composition.
- Empty composition toggles language without inserting text.
- Switching back permits normal Chinese candidate selection with Space/number keys.
- Shift held with a letter still types uppercase as intended.
- Ctrl/Alt shortcuts, punctuation, repeated toggles, and partially edited
  compositions do not lose or duplicate text.
- Explicit framework switching also commits raw input.
- Behavior works in Alacritty, the browser, GTK, and a Qt application.

The Shift behavior must be verified interactively; a successful Nix evaluation
cannot establish that the correct layer receives the key.

## 8. Distinctive directions for Koru

Only the accepted follow-up features are in scope. Use botanical names for
presentation while keeping commands and settings explicit.

| Direction | Concrete feature | Battery/work constraint | Success criterion |
| --- | --- | --- | --- |
| Fern identity | Shared palette, small static fern mark, consistent terminal/CLI typography | No animation or new rendering daemon | Recognizable across existing surfaces |
| Field Notes | On-demand power report with AC state, discharge rate, refresh rate, and active profile | Read existing sysfs/UPower data only when requested | Reproducible idle/workload comparisons |

Start with Fern identity and Field Notes. Record a battery baseline at fixed
brightness, refresh rate, network state, and workload before introducing any
further tuning. Do not claim measured battery improvements from theme colors or
add TLP/power-profiles-daemon alongside auto-cpufreq. Consider additional profiles
only after establishing a single authority for CPU/display policy.

## 9. Delivery sequence and quality gates

1. **Maintenance foundation:** add Justfile, pinned maintenance tools, completion,
   and documentation. Verify command listing, quoting, host validation, checks,
   and clear separation between build and activation.
2. **Module controls:** implement transactional flag edits and dependency checks;
   prove failed edits leave the original file unchanged.
3. **Input behavior:** implement raw-input commit settings and complete the
   interactive application matrix.
4. **Fern theme:** update semantic tokens and consumers; validate contrast and
   inspect the desktop/TTY at normal working brightness.
5. **Proxy experience:** extract and test the CLI, add completion/status, then add
   opt-in measurements with explicit resource limits.
6. **Documentation and optional identity:** align README and CI with actual recipe
   behavior; consider the first optional Koru feature after core acceptance.

Every implementation change should pass the existing Nix formatting/lint/dead-code
checks and appropriate system/home evaluation. Extend CI with shell checks and
focused behavioral tests for the module editor and proxy command contracts.
Keep network-dependent tests out of ordinary CI. Evaluate `all` to catch disabled
module regressions, but do not call it exhaustive testing of every flag combination.
Build affected outputs before activation and retain a usable prior generation.

Potential future file layout:

```text
Justfile
scripts/
  home-modules
  proxyctl.sh
completions/
  _proxyctl
lib/
  home-module-dependencies.nix
tests/
  home-modules/
  proxyctl/
```

Modify existing theme, input-method, shell, flake, CI, and README files in place;
do not create parallel replacement module trees. Add new files to Git's flake
source deliberately during implementation. Keep runtime caches, credentials,
probe results, and generated assets out of the tracked configuration.

## 10. Upstream references and implementation checks

These sources support the planned interfaces; upstream main branches can differ
from this repository's pins. Verify the locked versions before writing changes.

- [Rime ASCII composer implementation](https://github.com/rime/librime/blob/master/src/rime/gear/ascii_composer.cc): `commit_code` and ASCII-mode switching.
- [Fcitx5-Rime configuration definitions](https://github.com/fcitx/fcitx5-rime/blob/master/src/rimeengine.h): `SwitchInputMethodBehavior` and `CommitRawInput`.
- [Mihomo API documentation](https://wiki.metacubex.one/api/): node delay and traffic endpoints.
- [Just working directory](https://just.systems/man/en/working-directory.html): recipe directory behavior.
- [Just shell completions](https://just.systems/man/en/shell-completion-scripts.html): generated completion scripts.

Completion requires the implementation commits and automated quality gates in
addition to this reference. Activation and interactive desktop/input checks remain
deliberate post-review actions.
