{ ... }:
{
  homeManager.modules.gui =
    { lib, pkgs, ... }:
    {
      home.packages = with pkgs; [
        vlc
        # `jellyfin-media-player` is the same derivation under the pre-2.0 name.
        jellyfin-desktop
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

      # In place of the official `discord`, for two independent reasons no flag
      # fixes: its Electron is too old to drive the ScreenCast portal from a native
      # Wayland session (niri's portal stack is fine — it serves OBS and Firefox),
      # and the Linux client cannot share application audio, the sound of the
      # window being streamed, at all. Vesktop is Electron 43 and captures that
      # through the venmic PipeWire module it bundles. Enabling the module installs
      # the package as an .override resolving to the same derivation, so it stays
      # cached — don't also list it above.
      #
      # `settings` / `vencord.settings` are left undeclared deliberately: the
      # module renders them as store symlinks under ~/.config/vesktop, and Vesktop
      # silently falls back to defaults rather than read a symlinked settings file
      # (Vencord/Vesktop#1136). So the config stays mutable and is preserved below.
      programs.vesktop.enable = true;

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
    # Session token, Vencord settings and cache; mutable by design (see above).
    ".config/vesktop"
    ".config/Signal"
    ".config/obsidian"
    ".config/sone"
    # Not .config: it keeps both jellyfin-desktop.conf and the web client's
    # storage.json here, so without this the server address and login are gone
    # on every reboot.
    ".local/share/jellyfin-desktop"
  ];
}
