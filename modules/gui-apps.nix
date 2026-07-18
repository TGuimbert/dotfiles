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

    };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.directories = [
    ".config/discord"
    ".config/Signal"
    ".config/obsidian"
    ".config/tidal-hifi"
  ];
}
