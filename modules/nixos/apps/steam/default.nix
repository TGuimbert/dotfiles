{ lib, config, ... }:
with lib;
let
  cfg = config.tguimbert.apps.steam;
  username = config.tguimbert.user.name;
in
{
  options.tguimbert.apps.steam = {
    enable = mkEnableOption "Whether to enable support for Steam.";
  };
  config = mkIf cfg.enable {
    programs.steam.enable = true;
    hardware = {
      xpadneo.enable = true;
      steam-hardware.enable = true;
    };
    home-manager = mkIf config.tguimbert.system.impermanence.enable {
      users.${username} = {
        home.persistence."/persist-home/${username}" = {
          directories = [
            {
              directory = ".local/share/Steam";
              method = "symlink";
            }
            {
              directory = ".steam";
              method = "symlink";
            }
          ];
        };
      };
    };
  };
}
