{ config, pkgs, ... }:

let
  username = "tguimbert";
in {
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.11";

  home.sessionVariables = {
    EDITOR = "hx";
  };

  # Let Home Manager install and manage itself.
  programs = {
    home-manager.enable = true;

    fish.enable = true;
    starship.enable = true;
    bat.enable = true;

    git = {
      enable = true;
      aliases = {
        co = "checkout";
      };
      difftastic.enable = true;
    };

    gh = {
      enable = true;
      enableGitCredentialHelper = false;
      settings = {
        git_protocol = "ssh";

        aliases = {
          co = "pr checkout";
          pv = "pr view";
        };
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    alacritty.enable = true;
    wezterm = {
      enable = true;
      extraConfig = ''
        return {
          default_prog = { '/home/${username}/.nix-profile/bin/fish', '-l' },
          color_scheme = "Gruvbox dark, hard (base16)",
          hide_tab_bar_if_only_one_tab = true,
        }
      '';
    };
    helix = {
      enable = true;
      settings = {
        theme = "gruvbox";
      };
    };

    zellij = {
      enable = true;
      settings = {
        default_shell = "fish";
      };
    };
  };
 }
