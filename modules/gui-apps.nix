{ ... }:
{
  homeManager.modules.gui =
    { lib, pkgs, ... }:
    let
      # Chromium picks its OSCrypt backend by sniffing XDG_CURRENT_DESKTOP, and knows
      # only GNOME, KDE and a handful of other names — under `niri` it silently falls
      # back to the plaintext store, abandoning the login keyring keyring.nix unlocks.
      # So every Electron app here stopped using it the day GNOME was dropped. Only
      # Signal notices, and misleadingly: it records the backend it encrypted with, and
      # afterwards opens db.sqlite with a key derived from the plaintext store, which
      # SQLCipher reports as `SQLITE_NOTADB` — a decryption failure that reads as a
      # corrupt database. Obsidian and Vesktop just mint a new key and lose whatever the
      # old one protected.
      #
      # Wrapped rather than `.override { commandLineArgs = …; }`, the argument that
      # exists for this: nixpkgs deprecates it, and signal-desktop builds from source,
      # so overriding would blow the binary cache for one flag.
      withLibsecret =
        pkg:
        pkgs.symlinkJoin {
          name = "${lib.getName pkg}-libsecret";
          paths = [ pkg ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/${baseNameOf (lib.getExe pkg)} \
              --add-flags --password-store=gnome-libsecret
          '';
        };
    in
    {
      home.packages = with pkgs; [
        vlc
        # `jellyfin-media-player` is the same derivation under the pre-2.0 name.
        jellyfin-desktop
        remmina
        (withLibsecret obsidian)
        mullvad-browser
        (withLibsecret signal-desktop)
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
      programs.vesktop = {
        enable = true;
        # An overridable function rather than a plain derivation: the module installs
        # `cfg.package.override { withSystemVencord = …; }`, and a symlinkJoin has no
        # `.override`, so withLibsecret has to be re-applied on the far side of it.
        package = lib.makeOverridable (args: withLibsecret (pkgs.vesktop.override args)) { };
      };

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
