# Pinned GitHub host overrides; refresh the github-hosts flake input explicitly.
{ inputs, ... }:
{
  # The GitHub520 repo is a flake input pinned by flake.lock. Refresh it with
  # `nix flake update github-hosts`, then rebuild from the reviewed lock file.
  networking.extraHosts = builtins.readFile "${inputs.github-hosts}/hosts";
}
