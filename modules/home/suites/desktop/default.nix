{ pkgs, ... }:
{
  home.packages = with pkgs; [
    spotify
    discord
    vlc
    remmina
    anki-bin
    obsidian
    bitwarden
    signal-desktop
  ];
}
