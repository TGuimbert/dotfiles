{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.tguimbert.apps.clonehero;
  username = config.tguimbert.user.name;
in
{
  options.tguimbert.apps.clonehero = {
    enable = mkEnableOption "Whether to enable support for Clone Hero.";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      clonehero
    ];
    snowfallorg = mkIf config.tguimbert.system.impermanence.enable {
      users.${username}.home.config = {
        home.persistence."/persistent/home/${username}" = {
          directories = [
            ".clonehero"
            ".config/unity3d/srylain Inc_/Clone Hero"
          ];
        };
      };
    };
  };
}
