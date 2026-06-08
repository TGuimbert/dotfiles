{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.nushell = inputs.nix-wrapper-modules.wrappers.nushell.wrap {
        inherit pkgs;
        flags."--plugins" = "${pkgs.nushellPlugins.formats}/bin/nu_plugin_formats";
        "env.nu".content = ''
          $env.TERM = "foot"
          $env.EDITOR = "hx"
          $env.VISUAL = "hx"
          $env.BWS_SERVER_URL = "https://vault.bitwarden.eu"
          $env.CARAPACE_BRIDGES = "zsh,fish,bash,inshellisense"
          $env.XDG_DATA_DIRS = "$env.XDG_DATA_DIRS:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
          if (not ("~/.config/nushell/private.nu" | path exists)) {
            touch ~/.config/nushell/private.nu
          }

          # Generated here so config.nu can source them at parse time
          mkdir ~/.cache/carapace
          ${pkgs.carapace}/bin/carapace _carapace nushell | save --force ~/.cache/carapace/init.nu
          mkdir ~/.cache/zoxide
          ${pkgs.zoxide}/bin/zoxide init nushell | save --force ~/.cache/zoxide/init.nu
          mkdir ~/.cache/starship
          ${pkgs.starship}/bin/starship init nu | save --force ~/.cache/starship/init.nu
        '';
        "config.nu".content = ''
          use std

          # List existing Zellij layouts
          def available-layouts [] {
            ls ~/.config/zellij/layouts/ | get name | path parse | get stem
          }

          # Replace current Zellij tab with a new one based on the specified layout
          def replace-with-layout [layout: string@available-layouts] {
            let temp_tab_name = random chars
            zellij action rename-tab $temp_tab_name
            zellij action new-tab --layout $layout --name ($env.PWD | path basename)
            zellij action go-to-tab-name $temp_tab_name
            zellij action close-tab
          }

          # Open in a browser a local copy of the rust documentation
          def open-rust-doc [] {
            xdg-open (nix build fenix#latest.rust-docs --json --no-link | from json | first | get outputs.out | path join share/doc/rust/html/index.html)
          }

          source ~/.config/nushell/private.nu
          use ${pkgs.nu_scripts}/share/nu_scripts/aliases/eza/eza-aliases.nu *

          $env.config = ($env.config? | default {})
          $env.config.show_banner = false
          $env.config.buffer_editor = "hx"

          # Shell aliases
          alias ll = ls -la
          alias k = kubectl
          alias cat = bat
          alias b = bash -c
          alias bash = /run/current-system/sw/bin/bash

          # Git aliases
          alias gs = git status
          alias gd = git diff
          alias gds = git diff --staged
          alias ga = git add
          alias gap = git add --patch
          alias gc = git commit
          alias gca = git commit --amend --no-edit
          alias gce = git commit --amend
          alias gp = git push
          alias gu = git pull
          alias gco = git checkout
          alias gsw = git switch
          alias gn = git switch --create
          alias gl = git log --graph --all --pretty=format:"%C(magenta)%h %C(white) %an  %ar%C(blue)  %D%n%s%n"
          alias gb = git branch

          # Carapace completions
          source ~/.cache/carapace/init.nu

          # Zoxide
          source ~/.cache/zoxide/init.nu

          # Starship prompt
          source ~/.cache/starship/init.nu

          # Direnv hook
          $env.config.hooks = ($env.config.hooks? | default {})
          $env.config.hooks.pre_prompt = (
              $env.config.hooks.pre_prompt?
              | default []
              | append {||
                  ${pkgs.direnv}/bin/direnv export json
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
        '';
      };
    };

  flake.nixosModules.nushell =
    { pkgs, lib, config, inputs, ... }:
    {
      options.features.shell.nushell.enable = lib.mkEnableOption "nushell" // {
        default = true;
      };

      config = lib.mkIf config.features.shell.nushell.enable {
        environment.systemPackages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nushell ];

        home-manager.users.tguimbert = {
          programs.direnv = {
            enable = true;
            nix-direnv.enable = true;
            config.global = {
              hide_env_diff = true;
              warn_timeout = "15s";
            };
          };

          programs.carapace = {
            enable = true;
            enableNushellIntegration = false;
          };

          home.persistence."/persistent".files = [
            ".config/nushell/history.txt"
            ".config/nushell/private.nu"
            ".config/Bitwarden CLI/data.json"
          ];
        };
      };
    };
}
