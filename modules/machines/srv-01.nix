{ config, inputs, ... }:
{
  nixos.configurations.srv-01.module = {
    imports =
      (with config.nixos.modules; [
        base
        server
        traefik
        authelia
        lldap
        homepage
        restic
        calibre
        printing
      ])
      ++ [
        inputs.disko.nixosModules.disko

        ../../hosts/srv-01/hardware.nix
        ../../hosts/srv-01/disks.nix
      ];

    nixpkgs.hostPlatform = "x86_64-linux";

    system.stateVersion = "25.11";
  };
}
