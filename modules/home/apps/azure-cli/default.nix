{ lib
, config
, pkgs
, ...
}:
with lib;
let
  cfg = config.tguimbert.apps.azure-cli;
  azure-cli = pkgs.azure-cli.withExtensions [
    pkgs.azure-cli.extensions.ssh
  ];
in
{
  options.tguimbert.apps.azure-cli = {
    enable = mkEnableOption "Whether to enable support for azure-cli.";
  };
  config = mkIf cfg.enable {
    home.packages = [
      azure-cli
    ];
    home.persistence."/persistent/home/tguimbert" = {
      directories = [
        ".azure"
      ];
    };
  };
}
