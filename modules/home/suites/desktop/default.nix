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
    mullvad-browser
  ];
  programs.chromium.enable = true;
  tguimbert = {
    apps = {
      signal.enable = true;
      orca-slicer.enable = true;
      freecad.enable = true;
    };
  };
}
