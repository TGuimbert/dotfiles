{ ... }:
{
  programs = {
    zellij = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        default_shell = "nu";
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
  };
  home = {
    sessionVariables = {
      ZELLIJ_AUTO_ATTACH = "true";
      ZELLIJ_AUTO_EXIT = "true";
    };
  };
  xdg.configFile = {
    "zellij/layouts/yazelix.kdl".text = ''
      layout {
        tab_template name="ui" {
          pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
          }
          children
          pane size=1 borderless=true {
            plugin location="zellij:status-bar"
          }
        }

        default_tab_template {
          pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
          }
          pane split_direction="vertical" {
            pane name="sidebar" {
              command "yazi"
              size "100%"
            }
          }
          pane size=1 borderless=true {
            plugin location="zellij:status-bar"
          }
        }
      }
    '';
    "zellij/layouts/yazelix.swap.kdl".text = ''
      swap_tiled_layout name="one_pane" {
          ui exact_panes=4 {
              pane split_direction="vertical" {
                  pane name="sidebar" {
                      command "env"
                      args "YAZI_CONFIG_HOME=~/.config/yazelix/yazi/sidebar" "yazi"
                  	size "20%"
                  }
                  pane 
              }
          }
      }

      swap_tiled_layout name="sidebar_open_two_or_more_panes" {
          ui min_panes=5 {
              pane split_direction="vertical" {
                  pane name="sidebar" {
                      command "env"
                      args "YAZI_CONFIG_HOME=~/.config/yazelix/yazi/sidebar" "yazi"
                  	size "20%"
                  }
                  pane name="main" split_direction="vertical" {
                      pane
                      pane stacked=true { children; }
                  }
              }
          }
      }

      swap_tiled_layout name="sidebar_closed_two_or_more_panes" {
          ui min_panes=5 {
              pane split_direction="vertical" {
                  pane name="sidebar" {
                      command "env"
                      args "YAZI_CONFIG_HOME=~/.config/yazelix/yazi/sidebar" "yazi"
                  	size "1%"
                  }
                  pane name="main" split_direction="vertical" {
                      pane
                      pane stacked=true { children; }
                  }
              }
          }
      }
    '';
  };
}
