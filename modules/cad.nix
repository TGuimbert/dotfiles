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

    };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.directories = [
    ".config/OrcaSlicer"
    ".config/FreeCAD"
    ".cache/FreeCAD"
    ".cache/orca-slicer"
    ".local/share/FreeCAD"
  ];
}
