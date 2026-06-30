{ config, inputs, ... }:
{
  nixos.configurations.tuxedo = {
    module = {
      imports =
        (with config.nixos.modules; [
          base
          desktop
          docker
          scortex
        ])
        ++ [
          inputs.disko.nixosModules.disko

          inputs.nixos-hardware.nixosModules.tuxedo-infinitybook-pro14-gen9-intel
          inputs.tuxedo-nixos.nixosModules.default
          ../../hosts/tuxedo/hardware.nix
          ../../hosts/tuxedo/disks.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      system.stateVersion = "25.11";
    };
  };
}
