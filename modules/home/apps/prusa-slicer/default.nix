{ lib
, config
, pkgs
, ...
}:
with lib;
let
  cfg = config.tguimbert.apps.prusa-slicer;
in
{
  options.tguimbert.apps.prusa-slicer = {
    enable = mkEnableOption "Whether to enable support for Prusa Slicer.";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [ prusa-slicer ];
    home.persistence."/persistent/home/tguimbert" = {
      directories = [ ".config/PrusaSlicer" ];
    };
  };
}
