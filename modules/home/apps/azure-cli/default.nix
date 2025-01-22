{ lib
, config
, pkgs
, ...
}:
with lib;
let
  cfg = config.tguimbert.apps.azure-cli;
in
{
  options.tguimbert.apps.azure-cli = {
    enable = mkEnableOption "Whether to enable support for azure-cli.";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      azure-cli
    ];
    home.persistence."/persistent/home/tguimbert" = {
      directories = [
        ".azure"
      ];
    };
  };
}
