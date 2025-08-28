{
  pkgs,
  lib,
  config,
  ...
}:
{
  wayland.windowManager.sway = {
    enable = true;
    config = {
      modifier = "Mod4";
      terminal = "foot";
      bars = [
        {
          command = "waybar";
        }
      ];
      startup = [
        { command = "firefox"; }
      ];
      keybindings =
        let
          inherit (config.wayland.windowManager.sway.config) modifier;
        in
        lib.mkOptionDefault {
          "${modifier}+l" = "exec ${pkgs.swaylock}/bin/swaylock -fF";
        };
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

  home.packages = with pkgs; [ font-awesome ];

  programs = {
    waybar = {
      enable = true;
    };
    swaylock = {
      enable = true;
    };
  };

  services = {
    swayidle = {
      enable = true;
      timeouts = [
        {
          timeout = 300;
          command = "${pkgs.swaylock}/bin/swaylock -fF";
        }
        {
          timeout = 600;
          command = "${pkgs.sway}/bin/swaymsg \"output * power off\"";
        }
        {
          timeout = 900;
          command = "${pkgs.systemd}/bin/systemctl suspend";
        }
      ];
      events = [
        {
          event = "before-sleep";
          command = "${pkgs.swaylock}/bin/swaylock -fF";
        }
        {
          event = "after-resume";
          command = "${pkgs.sway}/bin/swaymsg \"output * power on\"";
        }
        {
          event = "lock";
          command = "lock";
        }
      ];
    };
  };

  stylix = {
    targets = {
      swaylock = {
        enable = true;
        useImage = true;
      };
    };
  };
}
