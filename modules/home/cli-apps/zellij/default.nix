{ ... }:
{
  programs = {
    fastfetch = {
      enable = true;
    };
    zellij = {
      enable = true;
      settings = {
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
  };
  home = {
    sessionVariables = {
      ZELLIJ_AUTO_ATTACH = "true";
      ZELLIJ_AUTO_EXIT = "true";
    };
  };
  xdg.configFile = {
    "zellij/layouts/homepage.kdl".text = ''
      layout {
        default_tab_template {
          pane size=1 borderless=true {
              plugin location="zellij:tab-bar"
          }
          children
          pane size=2 borderless=true {
              plugin location="zellij:status-bar"
          }
        }
        tab_template name="homepage" {
          pane size=1 borderless=true {
              plugin location="zellij:tab-bar"
          }
          pane split_direction="vertical" {
            pane name="Spotify" command="spotify_player" 
            pane split_direction="horizontal" {
              pane name="Bottom" command="btm"
              pane name="Fastfetch" command="nu" {
                args "-c" "fastfetch"
              }
            }
          }
        }
        homepage name="Homepage"
      }
    '';
    "zellij/layouts/rust.kdl".text = ''
      layout {
        pane size=1 borderless=true {
          plugin location="zellij:tab-bar"
        }
        pane split_direction="vertical" {
          pane name="hx" {
            command "direnv"
            args "exec" "." "nu" "-e" "hx"
            focus true
          }
          pane {
            pane name="cargo run" {
              command "direnv" 
              args "exec" "." "nu" "-c" "watch . --glob=**/*.rs {|| clear; cargo run }"
            }
            pane name="clippy" {
              command "direnv" 
              args "exec" "." "nu" "-c" "watch . --glob=**/*.rs {|| clear; cargo clippy }"
            }
          }
        }
        pane size=2 borderless=true {
          plugin location="zellij:status-bar"
        }
      }
    '';
  };
}
