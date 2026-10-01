# Global rules

## Environment & operating rules

These apply to every task, regardless of project.

### System
- NixOS 26.11 (nixos-unstable), host `koru`, user `koru`.
- Desktop is Niri (Alt = Mod1); terminal Kitty; editor nvim.
- Network is mainland China with NO VPN.

### Before choosing a tool
- Check what is already installed before picking a tool:
  - In the NixOS config repo: read `hosts/inventory.nix`, then `system/` and
    `home/` (see the repo section below).
  - In any shell: confirm with `command -v <tool>`.
- Prefer installed tools; when equivalents exist, use the modern one:
  `rg` over `grep`, `fd` over `find`, `eza` over `ls`, `bat` over `cat`,
  `jq` for JSON, `gh` for GitHub, `fzf` for fuzzy selection.
- Prefer opencode's native tools (Read / Grep / Glob) over shelling out.

### File conversion

- To convert Word / PowerPoint / Excel files to PDF, use LibreOffice (the only
  converter installed):
  `soffice --headless --convert-to pdf --outdir <dir> <file>`.
  It handles `.docx`, `.pptx` and `.xlsx`; do not reach for pandoc or similar.

### No self-installing
- Never install or temporarily provide tools on your own: no
  `nix profile install`, `nix shell`, `nix run`, `pip install`, `apt`, etc.
- If installed tools are insufficient, STOP and tell the user what is missing,
  why, and the options; wait for their decision before installing anything.

### Process management
- Never use `pkill` (it hangs on this machine).
- To stop a process: find the PID with `pgrep`, then `kill <PID>`.

### Network
- No VPN: do NOT use Google search. Use the configured websearch provider or a
  reachable engine (Bing / DuckDuckGo).
- Requests to risky hosts (GitHub and anything `github` / `raw.githubusercontent`
  / `ghcr` etc.) must be time-bounded: finish within 30s by default. If a task
  genuinely cannot fit, explain why first.

## NixOS configuration repo

Apply this section only when the task touches NixOS configuration, i.e. files
under `~/.config/nixos` or `~/Workspace/nixos`. Ignore it for unrelated work.

### Canonical location

- The live config is `~/.config/nixos` and is the only build entry point.
- `~/Workspace/nixos` is a stale copy. Never read or edit it for real changes.
- Flake outputs: `nixosConfigurations.koru` (full system),
  `homeConfigurations.koru` (standalone user profile) and
  `homeConfigurations.all` (evaluation-only).

### Never build

- Do NOT run `nixos-rebuild` or `home-manager switch` yourself.
- After changes, tell the user to run one of:
  - `sudo nixos-rebuild switch --flake ~/.config/nixos#koru`
  - `home-manager switch --flake ~/.config/nixos#koru` (user layer only)
- For a cheap check, `nix eval --raw ".#nixosConfigurations.koru.config.system.build.toplevel.drvPath"` is fine (read-only, does not build).

### Architecture

- Placement is decided by one question only: `system/` vs `home/` (activated by
  `nixos-rebuild` vs `home-manager switch`). There is no display boundary: all
  user modules live in `home/`.
- One topic/tool per file. Host identity lives in `hosts/<name>/`; the device
  registry is `hosts/inventory.nix`.

### The switchboard

- `home/modules-enables.nix` is the single switchboard: a flat `enable` map
  with one boolean per home module (`true` installs it, `false` keeps its file
  unused, and it doubles as the inventory). Keys and the `home/*.nix` modules
  must match in both directions (asserted in `home/default.nix`).
- The two control files `home/default.nix` and `home/modules-enables.nix` are
  skipped by discovery; every other `home/*.nix` is a module.
- Only the user layer can be switched at runtime; `system/` needs a rebuild.

### Theme

- `system/theme.nix` is the single source of truth for colors and fonts. It is
  pure data (not a module), passed to both layers via `specialArgs`. Never
  hardcode a color elsewhere; derive it from `theme`.

### Checks

- `nix flake check` runs formatting (`nixfmt`), lint (`statix`) and dead-code
  (`deadnix`) checks; `nix fmt` applies the formatter.
- `.github/workflows/check.yml` runs the same checks and also evaluates
  `homeConfigurations.koru` and `.all`, forcing every home module (including
  those no host imports) to evaluate.

### Comments

- English only, pure ASCII.
- File header: `# --- <name> ---` on line 1, then a one-line summary, optional
  detail, and a `Refs:` block when there is a source to cite.
- Section dividers: `# --- Section ---`.
- Explain WHY, not WHAT.
