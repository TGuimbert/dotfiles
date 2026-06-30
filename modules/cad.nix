{ ... }:
{
  homeManager.modules.gui =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        freecad
        orca-slicer
        sweethome3d.application
        calibre
      ];

      home.persistence."/persistent".directories = [
        ".config/OrcaSlicer"
        ".config/FreeCAD"
        ".cache/FreeCAD"
        ".cache/orca-slicer"
        ".local/share/FreeCAD"
      ];
    };
}
