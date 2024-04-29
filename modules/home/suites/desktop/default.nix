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
  ];
  tguimbert.apps.signal.enable = true;
}
