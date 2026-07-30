{ ... }:
{
  homeManager.modules.gui =
    { lib, pkgs, ... }:
    {
      home.packages = with pkgs; [
        discord
        vlc
        remmina
        obsidian
        mullvad-browser
        signal-desktop
        sone

        # Fallbacks for the GNOME panels/apps this desktop no longer ships;
        # noctalia's bar already covers volume, network, bluetooth and power.
        gnome-calculator
        pavucontrol # per-app audio routing
        baobab # disk usage (dust is the CLI equivalent)
        gnome-system-monitor # processes (bottom is the CLI equivalent)
      ];

      # Image viewer, in place of loupe.
      programs.swayimg.enable = true;

      xdg.mimeApps.defaultApplications = lib.genAttrs [
        "image/png"
        "image/jpeg"
        "image/gif"
        "image/webp"
        "image/bmp"
        "image/tiff"
        "image/svg+xml"
      ] (_: "swayimg.desktop");
    };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.directories = [
    ".config/discord"
    ".config/Signal"
    ".config/obsidian"
    ".config/sone"
  ];
}
