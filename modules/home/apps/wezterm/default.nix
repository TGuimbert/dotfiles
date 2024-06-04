{ pkgs, ... }:

{
  programs = {
    wezterm = {
      enable = true;
      extraConfig = ''
        return {
          default_prog = { 'fish', '-l' },
          color_scheme = "Gruvbox dark, hard (base16)",
          hide_tab_bar_if_only_one_tab = true,
          enable_kitty_keyboard = true,
          hide_mouse_cursor_when_typing = false,
        }
      '';
    };

    fish = {
      enable = true;
      interactiveShellInit = ''
        # Python config
        if test -f ~/.pip/pip.conf
            set -x PIP_EXTRA_INDEX_URL (sed -nE 's/extra-index-url = (.*)/\1/p' ~/.pip/pip.conf)
        end
      '';
      shellAliases = {
        k = "kubectl";
      };
    };

    zellij = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        default_shell = "fish";
      };
    };

    starship.enable = true;
    bat.enable = true;
    bottom.enable = true;
    eza = {
      enable = true;
      git = true;
      icons = true;
      extraOptions = [
        "--group-directories-first"
        "--header"
      ];
    };
    zoxide.enable = true;
    tealdeer = {
      enable = true;
      settings = {
        display = {
          use_pager = true;
          compact = true;
        };
        updates = {
          auto_update = false;
        };
      };
    };
  };
  home.packages = with pkgs; [
    fd
    procs
    sd
    du-dust
    ripgrep
  ];
  home.sessionVariables = {
    ZELLIJ_AUTO_ATTACH = "true";
    ZELLIJ_AUTO_EXIT = "true";
  };
}
