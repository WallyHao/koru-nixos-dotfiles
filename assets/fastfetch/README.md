# Koru logo

`koru-logo.png` is the user-supplied transparent 1254×1254 logo, copied directly
from `~/Downloads/koru.png`. Its colours, dimensions, and alpha channel are
preserved without conversion or recolouring.

`home/fastfetch.nix` uses this PNG directly with Kitty's image protocol and
installs it at `~/.config/fastfetch/koru-logo.png`. Apply the Home Manager
configuration to activate the change. No SVG renderer or generator is needed.
