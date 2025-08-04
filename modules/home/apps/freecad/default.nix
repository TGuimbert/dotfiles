{ lib
, config
, pkgs
, ...
}:
with lib;
let
  cfg = config.tguimbert.apps.freecad;
in
{
  options.tguimbert.apps.freecad = {
    enable = mkEnableOption "Whether to enable support for Orca Slicer.";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [ freecad ];
    home.persistence."/persistent/home/tguimbert" = {
      directories = [
        ".config/FreeCAD"
        ".cache/FreeCAD"
        ".local/share/FreeCAD"
      ];
    };
  };
}
