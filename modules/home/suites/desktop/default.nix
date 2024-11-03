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
  ];
  tguimbert = {
    apps = {
      signal.enable = true;
      prusa-slicer.enable = true;
      orca-slicer.enable = true;
    };
  };
}
