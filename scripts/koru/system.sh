#!/usr/bin/env bash
# Globals are initialized by koru.sh and common.sh.
# shellcheck disable=SC2154

koru_system() {
  local action=$1 target
  case $action in
    list) koru_generations "$system_profile" System ;;
    build)
      koru_repository; koru_lock
      koru_line heading 'System build and switch'
      koru_run "$sudo_command" nixos-rebuild switch --flake "$repository_root#koru" --no-update-lock-file
      ;;
    check)
      koru_repository; koru_lock
      koru_line heading 'System build check'
      koru_run nix build --no-link --no-update-lock-file "$repository_root#nixosConfigurations.koru.config.system.build.toplevel"
      ;;
    rollback)
      koru_lock
      target=$system_profile-$generation-link
      [[ -L $target && -x $target/bin/switch-to-configuration ]] || koru_error "Generation $generation is unavailable."
      koru_line heading "System rollback to $generation"
      koru_run "$sudo_command" nix-env --profile "$system_profile" --switch-generation "$generation"
      koru_run "$sudo_command" "$target/bin/switch-to-configuration" switch
      ;;
  esac
}
