{ ... }:
{
  homeManager.modules.gui =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        discord
        vlc
        remmina
        obsidian
        mullvad-browser
        signal-desktop
        tidal-hifi
      ];

      home.persistence."/persistent".directories = [
        ".config/discord"
        ".config/Signal"
        ".config/obsidian"
        ".config/tidal-hifi"
      ];
    };
}
