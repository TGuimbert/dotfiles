{ ... }:
{
  flake.nixosModules.zellij =
    { lib, config, ... }:
    {
      options.features.shell.zellij.enable = lib.mkEnableOption "zellij multiplexer" // {
        default = true;
      };

      config = lib.mkIf config.features.shell.zellij.enable {
        home-manager.users.tguimbert = {
          programs.zellij = {
            enable = true;
            settings = {
              theme = "stylix";
              default_shell = "nu";
              default_layout = "homepage";
              scrollback_editor = "hx";
              ui.pane_frames.rounded_corners = true;
              keybinds = {
                scroll = {
                  "unbind \"Ctrl s\"" = { };
                  "bind \"Ctrl y\"" = {
                    SwitchToMode = "Normal";
                  };
                };
                search = {
                  "unbind \"Ctrl s\"" = { };
                  "bind \"Ctrl y\"" = {
                    SwitchToMode = "Normal";
                  };
                };
                session = {
                  "unbind \"Ctrl o\"" = { };
                  "bind \"Ctrl e\"" = {
                    SwitchToMode = "Normal";
                  };
                  "unbind \"Ctrl s\"" = { };
                  "bind \"Ctrl y\"" = {
                    SwitchToMode = "Scroll";
                  };
                  "bind \"Ctrl q\"" = {
                    Quit = { };
                  };
                };
                "shared_except \"locked\"" = {
                  "unbind \"Alt i\"" = { };
                  "bind \"Alt w\"" = {
                    MoveTab = "Left";
                  };
                  "unbind \"Alt o\"" = { };
                  "bind \"Alt q\"" = {
                    MoveTab = "Right";
                  };
                  "unbind \"Alt n\"" = { };
                  "bind \"Alt m\"" = {
                    NewPane = "";
                  };
                  "unbind \"Ctrl q\"" = { };
                };
                "shared_except \"scroll\" \"locked\"" = {
                  "unbind \"Ctrl s\"" = { };
                  "bind \"Ctrl y\"" = {
                    SwitchToMode = "Scroll";
                  };
                };
                "shared_except \"session\" \"locked\"" = {
                  "unbind \"Ctrl o\"" = { };
                  "bind \"Ctrl e\"" = {
                    SwitchToMode = "Session";
                  };
                };
                "shared_except \"tmux\" \"locked\"" = {
                  "unbind \"Ctrl b\"" = { };
                };
              };
            };
          };

          xdg.configFile."zellij/layouts/rust.kdl".source = ../../../config/zellij/layouts/rust.kdl;
        };
      };
    };
}
