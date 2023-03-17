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
        }
      '';
    };

    fish = {
      enable = true;
      interactiveShellInit = ''
        zellij setup --generate-completion fish | source
        eval "$(zellij setup --generate-auto-start fish)"
      '';
      shellAliases = {
        k = "kubectl";
      };
    };

    zellij = {
      enable = true;
      settings = {
        default_shell = "fish";
      };
    };

    starship.enable = true;
    bat.enable = true;
    bottom.enable = true;
    exa = {
      enable = true;
      enableAliases = true;
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
}
