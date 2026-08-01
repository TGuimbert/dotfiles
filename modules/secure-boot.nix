{ inputs, ... }:
{
  # A named aspect rather than part of `desktop`: a bootloader is not a desktop
  # concern, and srv-01 wants Secure Boot too. Owns the whole `boot.loader` — for
  # a keyless install (lanzaboote cannot sign before /var/lib/sbctl exists) leave
  # it out of the host's imports rather than overriding it.
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
          # sbctl's own default keydir since 0.14, so there is no sbctl.conf to
          # keep in sync with this.
          pkiBundle = "/var/lib/sbctl";
        };
        bootspec.enable = true;
      };

      environment.systemPackages = [ pkgs.sbctl ];

      # Here rather than in preservation.nix so the keys follow the aspect onto
      # any host that imports it.
      preservation.preserveAt."/persistent".directories = [ "/var/lib/sbctl" ];
    };
}
