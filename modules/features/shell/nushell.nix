{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
{
  options.features.shell.nushell.enable = lib.mkEnableOption "nushell" // {
    default = true;
  };

  config = lib.mkIf config.features.shell.nushell.enable {
    home.packages = [
      (inputs.nix-wrapper-modules.wrappers.nushell.wrap {
        inherit pkgs;
        flags."--plugins" = "[${pkgs.nushellPlugins.formats}/bin/nu_plugin_formats]";
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
        '';
        "config.nu".content = ''
          source ${../../../config/nushell/config.nu}
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

          # Carapace completions
          mkdir ~/.cache/carapace
          ${pkgs.carapace}/bin/carapace _carapace nushell | save --force ~/.cache/carapace/init.nu
          source ~/.cache/carapace/init.nu

          # Zoxide
          mkdir ~/.cache/zoxide
          ${pkgs.zoxide}/bin/zoxide init nushell | save --force ~/.cache/zoxide/init.nu
          source ~/.cache/zoxide/init.nu

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
      })
    ];

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
}
