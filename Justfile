set shell := ["bash", "-euo", "pipefail", "-c"]

# List commands and short descriptions.
default: help

# List commands and short descriptions.
help:
    @just --list

# List available NixOS host outputs and architectures.
system-hosts-list:
    @./scripts/maintenance system-hosts-list

# Show the running host, OS/kernel, active system path and power source.
system-information:
    @./scripts/maintenance system-information

# List system generations and mark the current generation when available.
system-generations-list:
    @./scripts/maintenance system-generations-list

# List standalone Home Manager generations.
home-generations-list:
    @./scripts/maintenance home-generations-list

# Build a system configuration without activating it.
system-configuration-build host="koru" allow_battery="false":
    ./scripts/maintenance system-configuration build {{quote(host)}} {{quote(allow_battery)}}

# Temporarily activate a system configuration; services may restart.
system-configuration-test host="koru" allow_battery="false":
    ./scripts/maintenance system-configuration test {{quote(host)}} {{quote(allow_battery)}}

# Apply a system configuration and its embedded Home Manager profile.
system-configuration-switch host="koru" allow_battery="false":
    ./scripts/maintenance system-configuration switch {{quote(host)}} {{quote(allow_battery)}}

# Prepare a system configuration for the next boot without activating it now.
system-configuration-boot host="koru" allow_battery="false":
    ./scripts/maintenance system-configuration boot {{quote(host)}} {{quote(allow_battery)}}

# Build a standalone Home Manager profile without activating it.
home-configuration-build host="koru" allow_battery="false":
    ./scripts/maintenance home-configuration build {{quote(host)}} {{quote(allow_battery)}}

# Apply a standalone Home Manager profile without sudo.
home-configuration-switch host="koru" allow_battery="false":
    ./scripts/maintenance home-configuration switch {{quote(host)}} {{quote(allow_battery)}}

# Activate the preceding system generation; source files are unchanged.
system-generation-rollback:
    ./scripts/maintenance system-generation-rollback

# Activate a listed standalone Home Manager generation by numeric ID.
home-generation-activate generation:
    ./scripts/maintenance home-generation-activate {{quote(generation)}}

# Format maintained Nix sources in place.
configuration-format:
    ./scripts/maintenance configuration-format

# Check Nix formatting without rewriting files.
configuration-format-check:
    ./scripts/maintenance configuration-format-check

# Run statix using the repository configuration.
configuration-lint-check:
    ./scripts/maintenance configuration-lint-check

# Fail on dead Nix code.
configuration-dead-code-check:
    ./scripts/maintenance configuration-dead-code-check

# Evaluate the selected system and standalone Home Manager derivations.
configuration-evaluate host="koru":
    ./scripts/maintenance configuration-evaluate {{quote(host)}}

# Evaluate the all-modules Home Manager output; never activate it.
configuration-evaluate-all-home-modules:
    ./scripts/maintenance configuration-evaluate-all-home-modules

# Run flake checks plus explicit Home Manager output evaluation.
configuration-check allow_battery="false":
    ./scripts/maintenance configuration-check {{quote(allow_battery)}}

# Preview unreachable store paths and list retained generations.
garbage-collection-preview:
    ./scripts/maintenance garbage-collection-preview

# Collect unreachable paths without deleting generations first.
garbage-collection-run allow_battery="false":
    ./scripts/maintenance garbage-collection-run {{quote(allow_battery)}}

# Prune old system generations after explicit confirmation.
system-generations-prune age="7d" force="false" allow_battery="false":
    ./scripts/maintenance system-generations-prune {{quote(age)}} {{quote(force)}} {{quote(allow_battery)}}

# Expire old standalone Home Manager generations after confirmation.
home-generations-prune age="7d" force="false" allow_battery="false":
    ./scripts/maintenance home-generations-prune {{quote(age)}} {{quote(force)}} {{quote(allow_battery)}}

# Show configured Home Manager module flags.
home-modules-list:
    @./scripts/home-modules list

# Enable one module flag after transactional validation; do not activate it.
home-module-enable name:
    ./scripts/home-modules enable {{quote(name)}}

# Disable one module flag after transactional validation; do not activate it.
home-module-disable name:
    ./scripts/home-modules disable {{quote(name)}}

# Validate switchboard syntax, inventory, dependencies and selected evaluation.
home-modules-validate:
    ./scripts/home-modules validate
