#!/usr/bin/env bash
# Globals are initialized by common.sh.
# shellcheck disable=SC2154

koru_profile_source() {
  [[ -f $repository_root/profile/flake.nix && -f $repository_root/profile/flake.lock ]] ||
    koru_error 'Development profile source or lock file is missing.'
  profile_url=path:$repository_root/profile
  profile_attribute=packages.x86_64-linux.dev-tools
  profile_installable=$profile_url#dev-tools
}

koru_profile_manifest() {
  if [[ -e $dev_profile || -L $dev_profile ]]; then
    nix profile list --profile "$dev_profile" --json
  else
    printf '%s\n' '{"elements":{}}'
  fi
}

koru_profile_validate() {
  local manifest=$1
  # This profile belongs to one bundle from this repository. Do not overwrite
  # hand-installed entries or a same-named bundle from a different source.
  jq -e --arg url "$profile_url" --arg attribute "$profile_attribute" '
    (.elements | type == "object") and
    ((.elements | length) == 0 or
      ((.elements | keys) == ["dev-tools"] and
       .elements["dev-tools"].originalUrl == $url and
       .elements["dev-tools"].attrPath == $attribute and
       .elements["dev-tools"].active == true and
       (.elements["dev-tools"].storePaths | length) == 1))
  ' <<< "$manifest" >/dev/null ||
    koru_error 'Unmanaged profile entries found. Inspect with nix profile list --profile PATH; original profile preserved.'
}

koru_profile() {
  local action=$1 manifest installed expected target
  case $action in
    list) koru_generations "$dev_profile" 'Development profile' ;;
    check)
      koru_profile_source; koru_lock
      koru_line heading 'Development profile build check'
      koru_run nix build --no-link --no-update-lock-file "$profile_installable"
      ;;
    build)
      koru_profile_source; koru_lock
      manifest=$(koru_profile_manifest) || koru_error 'Cannot read development profile.'
      koru_profile_validate "$manifest"
      koru_line heading 'Development profile build and install'
      mkdir -p -- "$(dirname -- "$dev_profile")"
      # add/upgrade builds before publishing a new profile generation. Failed
      # builds leave the installed generation intact; no remove/add gap.
      if jq -e '.elements | length == 0' <<< "$manifest" >/dev/null; then
        koru_run nix profile install --profile "$dev_profile" --no-update-lock-file "$profile_installable"
      else
        koru_run nix profile upgrade --profile "$dev_profile" --no-update-lock-file dev-tools
      fi
      ;;
    status)
      koru_profile_source
      manifest=$(koru_profile_manifest) || koru_error 'Cannot read development profile.'
      koru_profile_validate "$manifest"
      koru_line heading 'Development profile'
      koru_field Path "$dev_profile"
      if jq -e '.elements | length == 0' <<< "$manifest" >/dev/null; then
        koru_line muted 'Not installed. Run koru profile build.'
        return 0
      fi
      installed=$(jq -r '.elements["dev-tools"].storePaths[0]' <<< "$manifest")
      expected=$(nix eval --no-update-lock-file --raw "$profile_installable.outPath") ||
        koru_error 'Cannot evaluate the current profile source.'
      if [[ $installed == "$expected" ]]; then
        koru_field Source 'Matches installed bundle'
      else
        koru_field Source 'Differs from installed bundle; run koru profile build to apply'
      fi
      [[ -r $installed/share/koru-dev/versions.json ]] || koru_error 'Installed version metadata is missing.'
      while IFS=$'\t' read -r name version; do
        koru_field "$name" "$version"
      done < <(jq -r 'to_entries[] | .key as $tool | .value | to_entries[] | [($tool + "/" + .key), .value] | @tsv' "$installed/share/koru-dev/versions.json")
      ;;
    rollback)
      koru_lock
      target=$dev_profile-$generation-link
      [[ -L $target ]] || koru_error "Generation $generation is unavailable."
      # Inspect the target without changing the current profile. A retained
      # unmanaged generation must not reintroduce unrelated packages.
      koru_profile_source
      manifest=$(nix profile list --profile "$target" --json) || koru_error 'Cannot read target generation.'
      koru_profile_validate "$manifest"
      koru_line heading "Development profile rollback to $generation"
      koru_run nix profile rollback --profile "$dev_profile" --to "$generation"
      ;;
  esac
}
