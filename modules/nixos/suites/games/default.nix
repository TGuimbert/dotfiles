{ config, lib, ... }:
with lib;
let
  cfg = config.tguimbert.suites.games;
in
{
  options.tguimbert.suites.games = {
    enable = mkEnableOption "Whether to enable common games configuration.";
  };
  config = mkIf cfg.enable {
    tguimbert.apps = {
      steam.enable = true;
      clonehero.enable = true;
    };
  };
}
