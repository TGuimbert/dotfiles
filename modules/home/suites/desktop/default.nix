{ pkgs, ... }:
{
  home.packages = with pkgs; [
    spotify
    discord
    vesktop
    vlc
    remmina
    anki-bin
    obsidian
    bitwarden
    sweethome3d.application
    freecad
    mullvad-browser
  ];
  tguimbert = {
    apps = {
      signal.enable = true;
      orca-slicer.enable = true;
    };
  };
}
