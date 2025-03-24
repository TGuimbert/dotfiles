{ ... }:
{
  wayland.windowManager.sway = {
    enable = true;
    config = rec {
      modifier = "Mod4";
      terminal = "foot";
      startup = [
        { command = "firefox"; }
      ];
      output = {
        "Acer Technologies XF270HU T78EE0048521" = {
          resolution = "2560x1440@143.856Hz";
          adaptive_sync = "on";
        };
        "Acer Technologies VG270U TEHEE004852A" = {
          resolution = "2560x1440@74.924Hz";
          adaptive_sync = "on";
        };
        DP-1 = {
          pos = "0 0";
        };
        DP-2 = {
          pos = "2560 0";
        };
      };
    };
  };
}
