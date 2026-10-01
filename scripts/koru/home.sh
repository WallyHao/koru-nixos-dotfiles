#!/usr/bin/env bash
# Globals are initialized by koru.sh and common.sh.
# shellcheck disable=SC2154

koru_home() {
  local action=$1 target data name state
  case $action in
    modules)
      data=$(KORU_REPO=$repository_root bash "$modules_command" list) || koru_error 'Cannot read module switches.'
      koru_line heading 'Home modules'
      while read -r name state; do
        if [[ $state == true ]]; then
          koru_line success "  enabled   $name"
        else
          koru_line muted "  disabled  $name"
        fi
      done <<< "$data"
      ;;
    enable | disable | validate)
      koru_lock
      koru_line heading "Home modules: $action"
      koru_run env KORU_REPO="$repository_root" bash "$modules_command" "$action" "${module_names[@]}"
      ;;
    list) koru_generations "$home_profile" Home ;;
    build)
      koru_repository; koru_lock
      koru_line heading 'Home build and switch'
      koru_run home-manager switch --flake "$repository_root#koru" --no-update-lock-file
      ;;
    check)
      koru_repository; koru_lock
      koru_line heading 'Home build check'
      koru_run nix build --no-link --no-update-lock-file "$repository_root#homeConfigurations.koru.activationPackage"
      ;;
    rollback)
      koru_lock
      target=$home_profile-$generation-link
      [[ -L $target && -x $target/activate ]] || koru_error "Generation $generation is unavailable."
      koru_line heading "Home rollback to $generation"
      koru_run "$target/activate"
      ;;
  esac
}
