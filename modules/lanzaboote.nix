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
          # sbctl's own default since 0.14 (sbctl.conf(5): keydir defaults to
          # /var/lib/sbctl/keys). Following it means no sbctl.conf to keep the
          # two in agreement, and state lands under /var/lib where it belongs —
          # GUID and files.db are state, not configuration.
          pkiBundle = "/var/lib/sbctl";
        };
        bootspec.enable = true;
      };

      environment.systemPackages = [ pkgs.sbctl ];

      # The signing keys are the aspect's own state, and root is a tmpfs: without
      # this they are gone on the next boot, leaving nothing that matches what the
      # firmware has enrolled. Lives here rather than in preservation.nix so it
      # follows the aspect onto any host that imports it.
      preservation.preserveAt."/persistent".directories = [ "/var/lib/sbctl" ];
    };
}
