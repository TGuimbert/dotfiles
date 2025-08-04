{ pkgs
, lib
, config
, ...
}:
let
  inherit (lib) mkAfter getExe;
in
{
  home.packages = with pkgs; [
    yubikey-manager
    rage
    age-plugin-yubikey
    bitwarden-cli
    bws
    jq
    dig
    dprint
    nixfmt-rfc-style
    asciinema
  ];

  programs = {
    home-manager.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      config = {
        global = {
          hide_env_diff = true;
          warn_timeout = "15s";
        };
      };
      enableNushellIntegration = false;
    };
    nushell.extraConfig = mkAfter ''
      $env.config = ($env.config? | default {})
      $env.config.hooks = ($env.config.hooks? | default {})
      $env.config.hooks.pre_prompt = (
          $env.config.hooks.pre_prompt?
          | default []
          | append {||
              ${getExe config.programs.direnv.package} export json
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
}
