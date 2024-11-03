{ lib
, config
, pkgs
, ...
}:
with lib;
let
  cfg = config.tguimbert.apps.orca-slicer;
in
{
  options.tguimbert.apps.orca-slicer = {
    enable = mkEnableOption "Whether to enable support for Orca Slicer.";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [ orca-slicer ];
    home.persistence."/persistent/home/tguimbert" = {
      directories = [
        ".config/OrcaSlicer"
        ".cache/orca-slicer"
      ];
    };
  };
}
