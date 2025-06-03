{ pkgs, ... }:

{
  programs = {
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

    starship = {
      enable = true;
      enableTransience = true;
      settings = {
        # Based on the gruvbox-rainbow preset
        format = "[](orange)$os$username[](bg:bright-yellow fg:orange)$directory[](fg:bright-yellow bg:bright-cyan)$git_branch$git_status[](fg:bright-cyan bg:bright-blue)$c$rust$golang$nodejs$php$java$kotlin$haskell$python[](fg:bright-blue bg:bright-black)$docker_context$conda[](fg:bright-black bg:base01)$time[ ](fg:base01)$line_break$character";
        os = {
          disabled = false;
          style = "bg:orange fg:bright-white";
          symbols = {
            Windows = "󰍲";
            Ubuntu = "󰕈";
            SUSE = "";
            Raspbian = "󰐿";
            Mint = "󰣭";
            Macos = "󰀵";
            Manjaro = "";
            Linux = "󰌽";
            Gentoo = "󰣨";
            Fedora = "󰣛";
            Alpine = "";
            Amazon = "";
            Android = "";
            Arch = "󰣇";
            Artix = "󰣇";
            CentOS = "";
            Debian = "󰣚";
            Redhat = "󱄛";
            RedHatEnterprise = "󱄛";
            NixOS = "";
          };
        };
        username = {
          show_always = true;
          style_user = "bg:orange fg:bright-white";
          style_root = "bg:orange fg:bright-white";
          format = "[ $user ]($style)";
        };
        directory = {
          style = "fg:bright-white bg:bright-yellow";
          format = "[ $path ]($style)";
          truncation_length = 3;
          truncation_symbol = "…/";
          substitutions = {
            Documents = "󰈙 ";
            Downloads = " ";
            Music = "󰝚 ";
            Pictures = " ";
            Workspace = "󰲋 ";
          };
        };
        git_branch = {
          symbol = "";
          style = "bg:bright-cyan";
          format = "[[ $symbol $branch ](fg:bright-white bg:bright-cyan)]($style)";
        };
        git_status = {
          style = "bg:bright-cyan";
          format = "[[($all_status$ahead_behind )](fg:bright-white bg:bright-cyan)]($style)";
        };
        nodejs = {
          symbol = "";
          style = "bg:bright-blue";
          format = "[[ $symbol( $version) ](fg:bright-white bg:bright-blue)]($style)";
        };
        c = {
          symbol = " ";
          style = "bg:bright-blue";
          format = "[[ $symbol( $version) ](fg:bright-white bg:bright-blue)]($style)";
        };
        rust = {
          symbol = "";
          style = "bg:bright-blue";
          format = "[[ $symbol( $version) ](fg:bright-white bg:bright-blue)]($style)";
        };
        golang = {
          symbol = "";
          style = "bg:bright-blue";
          format = "[[ $symbol( $version) ](fg:bright-white bg:bright-blue)]($style)";
        };
        php = {
          symbol = "";
          style = "bg:bright-blue";
          format = "[[ $symbol( $version) ](fg:bright-white bg:bright-blue)]($style)";
        };
        java = {
          symbol = " ";
          style = "bg:bright-blue";
          format = "[[ $symbol( $version) ](fg:bright-white bg:bright-blue)]($style)";
        };
        kotlin = {
          symbol = "";
          style = "bg:bright-blue";
          format = "[[ $symbol( $version) ](fg:bright-white bg:bright-blue)]($style)";
        };
        haskell = {
          symbol = "";
          style = "bg:bright-blue";
          format = "[[ $symbol( $version) ](fg:bright-white bg:bright-blue)]($style)";
        };
        python = {
          symbol = "";
          style = "bg:bright-blue";
          format = "[[ $symbol( $version) ](fg:bright-white bg:bright-blue)]($style)";
        };
        docker_context = {
          symbol = "";
          style = "bg:bright-black";
          format = "[[ $symbol( $context) ](fg:#83a598 bg:bright-black)]($style)";
        };
        conda = {
          style = "bg:bright-black";
          format = "[[ $symbol( $environment) ](fg:#83a598 bg:bright-black)]($style)";
        };
        time = {
          disabled = false;
          time_format = "%R";
          style = "bg:base01";
          format = "[[  $time ](fg:bright-white bg:base01)]($style)";
        };
        line_break = {
          disabled = false;
        };
        character = {
          disabled = false;
          error_symbol = "[✗](bold red) ";
        };
      };
    };
    bat.enable = true;
    bottom.enable = true;
    eza = {
      enable = true;
      git = true;
      icons = "auto";
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
  home = {
    packages = with pkgs; [
      fd
      procs
      sd
      du-dust
      ripgrep
    ];
    sessionVariables = {
      ZELLIJ_AUTO_ATTACH = "true";
      ZELLIJ_AUTO_EXIT = "true";
    };
    persistence."/persistent/home/tguimbert" = {
      files = [ ".config/fish/conf.d/private.fish" ];
    };
  };
}
