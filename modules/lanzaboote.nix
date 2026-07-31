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
    };
}
