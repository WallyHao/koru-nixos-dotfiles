# --- zen-browser ---
# Declarative Zen config via the zen-browser flake's home-manager module.
#
# Keyboard shortcuts are intentionally left at Zen's defaults. Only the three
# workspaces are declared, labelled "1"/"2"/"3"; spacesForce = true recreates
# them and prunes any stale ones.
{ inputs, ... }:
let
  # Zen switches workspaces by ARRAY INDEX (ZenSpaceManager.shortcutSwitchTo ->
  # _workspaceCache[index]), and the home-manager session writer appends
  # declared spaces in attribute-name (alphabetical) order. So keys are
  # "1"/"2"/"3" to get the 1,2,3 order. UUIDs are fresh so the writer appends
  # them in that order and (with spacesForce) prunes any stale ones.
  # Zen requires UUID v4 ids for spaces.
  spaces = {
    "1" = {
      name = "1";
      icon = "1";
      id = "d96ba7c5-0723-4a7c-8c39-d8e3a974cc12";
      position = 1;
    };
    "2" = {
      name = "2";
      icon = "2";
      id = "0a98c53b-5761-407e-88b2-c21b9c2cc6cf";
      position = 2;
    };
    "3" = {
      name = "3";
      icon = "3";
      id = "5ccf13bb-802c-478f-95b7-65655ec66299";
      position = 3;
    };
  };
in
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    profiles.default = {
      path = "r8mq32kc.Default Profile";
      isDefault = true;

      # Open on workspace 1.
      settings."zen.workspaces.active" = "{${spaces."1".id}}";

      spacesForce = true;
      # Pass the ordered attrset straight through (name/icon/id/position are
      # all valid space options).
      inherit spaces;
    };
  };
}
