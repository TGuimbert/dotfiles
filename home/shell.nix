{
  pkgs,
  lib,
  config,
  ...
}:
{
  programs = {
    # Terminal
    foot = {
      enable = true;
      server.enable = true;
      settings = {
        main = {
          shell = "nu -c 'zellij -l welcome'";
          initial-window-mode = "maximized";
        };
      };
    };

    # Editor
    helix = {
      enable = true;
      defaultEditor = true;
      extraPackages = with pkgs; [
        marksman
        ltex-ls
        yaml-language-server
        nodePackages.prettier
      ];
      ignores = [
        ".obsidian/"
        ".direnv/"
        ".envrc"
      ];
      languages = {
        language = [
          {
            name = "markdown";
            language-servers = [
              "marksman"
              "ltex-ls"
            ];
            formatter = {
              command = "dprint";
              args = [
                "fmt"
                "--stdin"
                "md"
              ];
            };
            auto-format = true;
          }
          {
            name = "nix";
            formatter = {
              command = "nixfmt";
            };
            auto-format = true;
          }
          {
            name = "go";
            auto-format = true;
            formatter = {
              command = "goimports";
            };
          }
          {
            name = "yaml";
            auto-format = true;
            formatter = {
              command = "prettier";
              args = [
                "--parser"
                "yaml"
              ];
            };
          }
          {
            name = "python";
            language-servers = [
              "ruff"
              "pylsp"
            ];
            auto-format = true;
          }
          {
            name = "hcl";
            language-id = "opentofu";
            scope = "source.hcl";
            file-types = [
              "tf"
              "tofu"
              "tfvars"
            ];
            auto-format = true;
            comment-token = "#";
            block-comment-tokens = {
              start = "/*";
              end = "*/";
            };
            indent = {
              tab-width = 2;
              unit = "  ";
            };
            language-servers = [ "tofu-ls" ];
          }
        ];
        language-server = {
          yaml-language-server.config.yaml = {
            completion = true;
            validation = true;
            hover = true;
            schemas = {
              "https://json.schemastore.org/github-workflow.json" = ".github/workflows/*.{yml,yaml}";
              "https://raw.githubusercontent.com/ansible-community/schemas/main/f/ansible-tasks.json" =
                "roles/{tasks,handlers}/*.{yml,yaml}";
              kubernetes = [
                "*deployment*.yaml"
                "*service*.yaml"
                "*configmap*.yaml"
                "*secret*.yaml"
                "*pod*.yaml"
                "*namespace*.yaml"
                "*ingress*.yaml"
              ];
              "https://raw.githubusercontent.com/SchemaStore/schemastore/master/src/schemas/json/kustomization.json" =
                [
                  "*kustomization.yaml"
                  "*kustomize.yaml"
                ];
            };
          };
          pylsp.config.pylsp = {
            plugins.pylsp_mypy.enabled = true;
            plugins.pylsp_mypy.live_mode = true;
          };
          ruff = {
            command = "ruff";
            arg = [ "server" ];
          };
          tofu-ls = {
            command = "tofu-ls";
            args = [ "serve" ];
          };
        };
      };
      settings = {
        editor = {
          bufferline = "multiple";
          color-modes = true;
          rulers = [ 120 ];
          line-number = "relative";
          end-of-line-diagnostics = "hint";
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

        editor.statusline = {
          left = [
            "mode"
            "spinner"
            "version-control"
            "file-name"
            "read-only-indicator"
            "file-modification-indicator"
          ];
        };

        editor.inline-diagnostics = {
          cursor-line = "error";
        };
      };
    };

    # Shell
    nushell = {
      enable = true;
      plugins = [ pkgs.nushellPlugins.formats ];
      configFile.source = ./nushell/config.nu;
      environmentVariables = {
        TERM = "foot";
        EDITOR = "hx";
        VISUAL = "hx";
        BWS_SERVER_URL = "https://vault.bitwarden.eu";
        CARAPACE_BRIDGES = "zsh,fish,bash,inshellisense";
      };
      extraEnv = ''
        if (not ("~/.config/nushell/private.nu" | path exists)) {
          touch ~/.config/nushell/private.nu
        }
      '';
      extraConfig = ''
        source ~/.config/nushell/private.nu
        use ${pkgs.nu_scripts}/share/nu_scripts/aliases/eza/eza-aliases.nu *
        # Fix for home-manager 25.04, to be removed on 25.11
        $env.config = ($env.config? | default {})
        $env.config.hooks = ($env.config.hooks? | default {})
        $env.config.hooks.pre_prompt = (
            $env.config.hooks.pre_prompt?
            | default []
            | append {||
                ${lib.getExe config.programs.direnv.package} export json
                | from json --strict
                | default {}
                | items {|key, value|
                    let value = do (
                        {
                          "PATH": {
                            from_string: {|s| $s | split row (char esep) | path expand --no-symlink }
                            to_string: {|v| $v | path expand --no-symlink | str join (char esep) }
                          }
                        }
                        | merge ($env.ENV_CONVERSIONS? | default {})
                        | get ([[value, optional, insensitive]; [$key, true, true] [from_string, true, false]] | into cell-path)
                        | if ($in | is-empty) { {|x| $x} } else { $in }
                    ) $value
                    return [ $key $value ]
                }
                | into record
                | load-env
            }
        )
        if ("~/.gnupg/S.gpg-agent.ssh" | path exists) {
          $env.SSH_AUTH_SOCK = "~/.gnupg/S.gpg-agent.ssh"
          $env.GPG_TTY = ^tty
          ^gpg-connect-agent updatestartuptty /bye
        }
      '';
    };

    # Multiplexer
    zellij = {
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

    # CLI tools
    bat.enable = true;
    bottom.enable = true;
    fastfetch.enable = true;
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

    # Starship
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

    # Direnv
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      config = {
        global = {
          hide_env_diff = true;
          warn_timeout = "15s";
        };
      };
      # Enable for home-manager 25.11
      enableNushellIntegration = false;
    };

    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    # K9s
    k9s.enable = true;
  };

  xdg.configFile = {
    "zellij/layouts/rust.kdl".source = ./zellij/layouts/rust.kdl;
    "k9s/plugins.yaml".source = ./k9s/plugins.yaml;
    "k9s/views.yaml".source = ./k9s/views.yaml;
  };

  home = {
    packages = with pkgs; [
      fd
      procs
      sd
      dust
      ripgrep
      bitwarden-cli
    ];

    sessionVariables = {
      ZELLIJ_AUTO_ATTACH = "true";
      ZELLIJ_AUTO_EXIT = "true";
    };

    persistence."/persistent/home/tguimbert" = {
      files = [
        ".config/nushell/history.txt"
        ".config/nushell/private.nu"
        ".config/Bitwarden CLI/data.json"
      ];
    };
  };
}
