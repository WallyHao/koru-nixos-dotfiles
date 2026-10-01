# --- btop ---
# System monitor: Koru Fern theme generated from the global theme. Box borders
# (cpu/mem/net/proc_box + div_line) stay muted-alt.
{ theme, ... }:
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "koru-fern";
      theme_background = false;
      truecolor = true;
      rounded_corners = true;
      graph_symbol = "braille";
      update_ms = 2000;
    };
    themes.koru-fern = ''
      # Koru Fern
      # btop theme generated from the global system/theme.nix

      # Main bg
      theme[main_bg]="${theme.bg}"

      # Main text color
      theme[main_fg]="${theme.fg}"

      # Title color for boxes (soft yellow accent)
      theme[title]="${theme.accent-yellow}"

      # Highlight color for keyboard shortcuts
      theme[hi_fg]="${theme.accent-yellow-bright}"

      # Background color of selected item in processes box
      theme[selected_bg]="${theme.bg-alt}"

      # Foreground color of selected item in processes box
      theme[selected_fg]="${theme.fg}"

      # Color of inactive/disabled text
      theme[inactive_fg]="${theme.muted-alt}"

      # Misc colors for processes box (green accent)
      theme[proc_misc]="${theme.ansi-bright.green}"

      # All borders use the same color
      theme[cpu_box]="${theme.muted-alt}"
      theme[mem_box]="${theme.muted-alt}"
      theme[net_box]="${theme.muted-alt}"
      theme[proc_box]="${theme.muted-alt}"

      # Box divider line and small boxes line color
      theme[div_line]="${theme.muted-alt}"

      # Temperature graph colors
      theme[temp_start]="${theme.accent-deep}"
      theme[temp_mid]="${theme.accent}"
      theme[temp_end]="${theme.ansi.red}"

      # CPU graph colors
      theme[cpu_start]="${theme.accent-deep}"
      theme[cpu_mid]="${theme.ansi.red}"
      theme[cpu_end]="${theme.fg}"

      # Mem/Disk free meter
      theme[free_start]="${theme.black}"
      theme[free_mid]="${theme.muted-alt}"
      theme[free_end]="${theme.accent-deep}"

      # Mem/Disk cached meter
      theme[cached_start]="${theme.black}"
      theme[cached_mid]="${theme.muted-alt}"
      theme[cached_end]="${theme.accent}"

      # Mem/Disk available meter (green: available space reads as "good")
      theme[available_start]="${theme.black}"
      theme[available_mid]="${theme.ansi.green}"
      theme[available_end]="${theme.ansi-bright.green}"

      # Mem/Disk used meter
      theme[used_start]="${theme.accent-deep}"
      theme[used_mid]="${theme.ansi.red}"
      theme[used_end]="${theme.fg}"

      # Download graph colors (green: incoming data)
      theme[download_start]="${theme.black}"
      theme[download_mid]="${theme.ansi.green}"
      theme[download_end]="${theme.ansi-bright.green}"

      # Upload graph colors
      theme[upload_start]="${theme.black}"
      theme[upload_mid]="${theme.muted-alt}"
      theme[upload_end]="${theme.accent}"
    '';
  };
}
