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
    prusa-slicer
  ];
  tguimbert.apps.signal.enable = true;
}
