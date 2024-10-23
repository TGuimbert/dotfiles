{ pkgs, ... }:
let
  private_config_path = ".config/nushell/private.nu";
in
{
  programs = {
    nushell = {
      enable = true;
      configFile.source = ./config.nu;
      extraEnv = ''
        $env.NU_PLUGIN_DIRS = (
          $env.NU_PLUGIN_DIRS |
          append ${pkgs.nushellPlugins.formats}/bin
        )

        if (not ("~/${private_config_path}" | path exists)) {
          touch ~/${private_config_path}
        }
      '';
      extraConfig = ''
        plugin use formats
        source ~/${private_config_path}
      '';
    };
    carapace = {
      enable = true;
    };
  };

  home = {
    persistence."/persistent/home/tguimbert" = {
      files = [
        ".config/nushell/history.txt"
        private_config_path
      ];
    };
  };
}
