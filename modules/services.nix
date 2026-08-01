{ ... }:
{
  nixos.modules.base = {
    services = {
      openssh = {
        enable = true;
        # ed25519 only — an RSA host key buys nothing here and would be a second
        # key to preserve (see ./preservation.nix).
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      # Printer/host discovery on the LAN. `publish` is what makes `<host>.local`
      # answer, which is how the justfile's remote recipes reach srv-01.
      # openFirewall already defaults to true.
      avahi = {
        enable = true;
        nssmdns4 = true;
        publish = {
          enable = true;
          addresses = true;
          workstation = true;
        };
      };

      # Every host is bare metal on btrfs-on-LUKS, srv-01 included.
      btrfs.autoScrub.enable = true;
      fwupd.enable = true;
      smartd.enable = true;
    };
  };

  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      services = {
        # No printer GUI: GNOME's control-center panel is gone and
        # system-config-printer costs ~170 MB. Administer at http://localhost:631.
        # This is the driverless *client* of srv-01's print server — the driver
        # and ippeveprinter live in modules/server/printing.nix.
        printing.enable = true;
        # Thunderbolt device authorization (griffin's dock); /var/lib/boltd is
        # already preserved.
        hardware.bolt.enable = true;
        # Smartcard access for gpg's scdaemon (modules/gpg.nix sets disable-ccid, so
        # it goes through pcscd rather than claiming the yubikey itself, leaving the
        # card usable by ykman and age-plugin-yubikey).
        pcscd.enable = true;
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

      hardware.keyboard.qmk.enable = true;

      environment.systemPackages = with pkgs; [
        qemu
      ];
    };
}
