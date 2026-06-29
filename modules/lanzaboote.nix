{ inputs, ... }:
{
  nixos.modules.desktop =
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
