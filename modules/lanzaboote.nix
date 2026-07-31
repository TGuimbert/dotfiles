{ inputs, ... }:
{
  # A named aspect rather than part of `desktop`: srv-01 wants Secure Boot too,
  # and a bootloader is not a desktop concern. Hosts opt in by importing it.
  nixos.modules.secureBoot =
    { pkgs, ... }:
    {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      boot = {
        loader = {
          systemd-boot.enable = false;
          efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot";
          };
          timeout = 0;
        };
        lanzaboote = {
          enable = true;
          pkiBundle = "/etc/secureboot";
        };
        bootspec.enable = true;
      };

      environment.systemPackages = [ pkgs.sbctl ];

      # sbctl >= 0.14 defaults keydir to /var/lib/sbctl/keys, while pkiBundle
      # above (and the keys leshen and griffin have had since 2024) live in
      # /etc/secureboot. Left alone the two disagree: `sbctl create-keys` writes
      # where lanzaboote will not look, and lanzaboote fails to sign with
      # "Get stub name: No such file or directory". Point sbctl at the bundle.
      environment.etc."sbctl/sbctl.conf".text = ''
        keydir: /etc/secureboot/keys
        guid: /etc/secureboot/GUID
        files_db: /etc/secureboot/files.db
        bundles_db: /etc/secureboot/bundles.db
      '';

      # The signing keys are the aspect's own state, and root is a tmpfs: without
      # this they are gone on the next boot, leaving nothing that matches what the
      # firmware has enrolled. Lives here rather than in preservation.nix so it
      # follows the aspect onto any host that imports it.
      preservation.preserveAt."/persistent".directories = [ "/etc/secureboot" ];
    };
}
