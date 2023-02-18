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

  home.packages = with pkgs; [
    spotify
    yubikey-manager
    rage
    age-plugin-yubikey
    bitwarden-cli
    kubectl
    minikube
    discord
  ];

  home.file = {
    minikubeConfig = {
      target = ".minikube/config/config.json";
      text = builtins.toJSON {
        container-runtime = "containerd";
        rootless = true;
      };
    };
  };

  services.gpg-agent = {
    enable = true;
    pinentryFlavor = "gnome3";
  };

  # Let Home Manager install and manage itself.
  programs = {
    home-manager.enable = true;

    firefox.enable = true;

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
    starship.enable = true;
    bat.enable = true;

    gpg = {
      enable = true;
    };

    git = {
      enable = true;
      userName = "TGuimbert";
      userEmail = "33598842+TGuimbert@users.noreply.github.com";
      signing = {
        signByDefault = true;
        key = "11C1D08CC148FEBC";
      };
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

    wezterm = {
      enable = true;
      extraConfig = ''
        return {
          default_prog = { '/home/${username}/.nix-profile/bin/fish', '-l' },
          color_scheme = "Gruvbox dark, hard (base16)",
          hide_tab_bar_if_only_one_tab = true,
          enable_kitty_keyboard = true,
        }
      '';
    };

    helix = {
      enable = true;
      settings = {
        theme = "gruvbox";

        editor = {
          bufferline = "multiple";
          color-modes = true;
        };

        editor.cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };

        editor.indent-guides = {
          render = true;
        };

        editor.file-picker = {
          hidden = false;
        };

        keys.normal = {
          g = "move_char_left";
          t = "move_line_down";
          s = "move_line_up";
          n = "move_char_right";

          j = "find_till_char";
          J = "till_prev_char";

          T = "join_selections";

          l = "search_next";
          L = "search_prev";

          k = "select_regex";
          K = "split_selection";
          "A-k" = "split_selection_on_newline";

          h = {
            h = "goto_file_start";
            e = "goto_last_line";
            f = "goto_file";
            g = "goto_line_start";
            n = "goto_line_end";
            s = "goto_first_nonwhitespace";
            t = "goto_window_top";
            c = "goto_window_center";
            b = "goto_window_bottom";
            d = "goto_definition";
            y = "goto_type_definition";
            r = "goto_reference";
            i = "goto_implementation";
            a = "goto_last_accessed_file";
            m = "goto_last_modified_file";
            l = "goto_next_buffer";
            p = "goto_previous_buffer";
            "." = "goto_last_modification";
          };
        };

        keys.select = {
          l = "extend_search_next";
          L = "extend_search_prev";
        };
      };
    };

    zellij = {
      enable = true;
      settings = {
        default_shell = "fish";
      };
    };

    bottom.enable = true;
    k9s.enable = true;
  };
 }
