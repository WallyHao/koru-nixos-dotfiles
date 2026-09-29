# Niri application launcher with frecency ordering.
{
  lib,
  pkgs,
  theme,
  ...
}:
let
  # Coreutils + gawk for the frecency wrapper, prepended to PATH at run time
  # (the wrapper later execs the picked app, so the original PATH is kept).
  scriptPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.gawk
  ];
  # wmenu styling (colors/font from the global theme), shared with
  # clipboard-history.nix via lib/module-discovery.nix. Plain `wmenu` preserves the order of its
  # stdin, so the frecency wrapper below can rank by usage.
  wmenu-opts = import ../../lib/wmenu-style.nix { inherit lib theme; };

  # Frecency launcher: lists the same $PATH executables wmenu-run would, but
  # ranks them by usage so recently/frequently used apps come first. Score =
  # count / (1 + days since last use). History lives in ~/.cache/wmenu/history.
  wmenu-frecency = pkgs.writeShellScriptBin "wmenu-frecency" ''
    set -eu
    # Frecency scoring leans on coreutils + gawk; pin them instead of trusting
    # the ambient PATH. Keep the ambient PATH too so the picked app below can
    # still be exec'd from the user profile, but remember it: the candidate
    # list must mirror wmenu-run's, so the pinned tool dirs (whose coreutils
    # ships `[`) must not leak into it.
    ambient_path=$PATH
    export PATH=${scriptPath}:$PATH

    cache="''${XDG_CACHE_HOME:-$HOME/.cache}/wmenu"
    history="$cache/history"
    mkdir -p "$cache"
    touch "$history"

    # Candidate list: non-hidden executables in $PATH, deduplicated. Skip `[`
    # and `test` (coreutils' own aliases, present in /run/current-system/sw/bin):
    # they are not launchable apps and just exit non-zero.
    list=$(mktemp)
    trap 'rm -f "$list"' EXIT
    IFS=: read -ra dirs <<<"$ambient_path"
    for d in "''${dirs[@]}"; do
      [ -d "$d" ] || continue
      for f in "$d"/*; do
        case "''${f##*/}" in
          "[" | test) continue ;;
        esac
        if [ -x "$f" ] && [ ! -d "$f" ]; then printf '%s\n' "''${f##*/}"; fi
      done
    done | sort -u > "$list"

    # Usage table from the history file (count, last-used epoch, name).
    declare -A count last
    while IFS=$'\t' read -r c l n; do
      [ -n "''${n:-}" ] || continue
      count["$n"]="$c"
      last["$n"]="$l"
    done < "$history"

    now=$(date +%s)
    selection=$(
      while IFS= read -r name; do
        c="''${count["$name"]:-0}"
        l="''${last["$name"]:-0}"
        age=$(( (now - l) / 86400 ))
        printf '%d\t%s\n' "$(( c * 1000 / (1 + age) ))" "$name"
      done < "$list" | sort -srn -k1,1 | cut -f2- | ${lib.getExe pkgs.wmenu} ${wmenu-opts}
    ) || exit 0
    [ -n "$selection" ] || exit 0

    # Record the choice (count++, timestamp=now), then run it.
    tmp=$(mktemp)
    awk -F '\t' -v name="$selection" -v now="$now" '
      $3 == name { print $1 + 1 "\t" now "\t" name; found = 1; next }
      { print }
      END { if (!found) print "1\t" now "\t" name }
    ' "$history" > "$tmp"
    mv "$tmp" "$history"

    exec /bin/sh -c "$selection"
  '';
in
{
  home.packages = [
    wmenu-frecency
    pkgs.wmenu
  ];
}
