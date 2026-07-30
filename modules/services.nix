{ ... }:
{
  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      services = {
        openssh.enable = true;
        printing.enable = true;
        fwupd.enable = true;
        # Smartcard access for gpg's scdaemon (modules/gpg.nix sets disable-ccid, so
        # it goes through pcscd rather than claiming the yubikey itself, leaving the
        # card usable by ykman and age-plugin-yubikey).
        pcscd.enable = true;
        btrfs.autoScrub.enable = true;
        avahi.nssmdns4 = true;
        tailscale = {
          enable = true;
          useRoutingFeatures = "client";
          extraSetFlags = [
            "--operator=tguimbert"
          ];
        };
      };

      # Drop the `-x` (--auto-exit) the nixpkgs module hardcodes: pcscd quits after
      # 60 s idle, and taking the reader down powers off the card, so the yubikey's
      # OpenPGP applet loses its verified PIN. With the signature PIN *not* forced on
      # the card, a PIN entry should otherwise cover every later signature — instead
      # each commit a minute apart asked again. /etc/reader.conf is the same file the
      # module points at.
      # mkForce, not a plain list: these merge, and the winner would then depend on
      # definition order. The leading "" resets the vendor unit's ExecStart.
      systemd.services.pcscd.serviceConfig.ExecStart = lib.mkForce [
        ""
        "${
          lib.getExe (if config.security.polkit.enable then pkgs.pcscliteWithPolkit else pkgs.pcsclite)
        } -f -c /etc/reader.conf"
      ];

      xdg.portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gnome
        ];
      };

      hardware.keyboard.qmk.enable = true;

      environment.systemPackages = with pkgs; [
        qemu
      ];
    };
}
