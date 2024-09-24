{ ... }:
{
  programs = {
    zellij = {
      enable = true;
      enableFishIntegration = true;
    };
  };
  home.sessionVariables = {
    ZELLIJ_AUTO_ATTACH = "true";
    ZELLIJ_AUTO_EXIT = "true";
  };
  home.file.".config/zellij/config.kdl" = {
    text = ''
      default_shell "fish"
      ui {
        pane_frames {
          rounded_corners true
        }
      }

      // Remove collisions with Helix keybindings
      keybinds {
        scroll {
          unbind "Ctrl s"
          bind "Ctrl y" { SwitchToMode "Normal"; }
        }
        search {
          unbind "Ctrl s"
          bind "Ctrl y" { SwitchToMode "Normal"; }
        }
        session {
          unbind "Ctrl o"
          bind "Ctrl e" { SwitchToMode "Normal"; }
          unbind "Ctrl s"
          bind "Ctrl y" { SwitchToMode "Normal"; }
        }
        shared_except "locked" {
          unbind "Alt i"
          bind "Alt w" { MoveTab "Left"; }
          unbind "Alt o"
          bind "Alt q" { MoveTab "Right"; }
          unbind "Alt n"
          bind "Alt m" { NewTab; }
        }
        shared_except "scroll" "locked" {
          unbind "Ctrl s"
          bind "Ctrl y" { SwitchToMode "Scroll"; }
        }
        shared_except "session" "locked" {
          unbind "Ctrl o"
          bind "Ctrl e" { SwitchToMode "Session"; }
        }
        shared_except "tmux" "locked" {
          unbind "Ctrl b"
        }
      }
    '';
  };
}
