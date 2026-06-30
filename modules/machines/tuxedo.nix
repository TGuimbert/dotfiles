{ config, inputs, ... }:
{
  nixos.configurations.tuxedo = {
    module = {
      imports =
        (with config.nixos.modules; [
          base
          desktop
        ])
        ++ [
          inputs.disko.nixosModules.disko

          inputs.nixos-hardware.nixosModules.tuxedo-infinitybook-pro14-gen9-intel
          inputs.tuxedo-nixos.nixosModules.default
          ../../hosts/tuxedo/hardware.nix
          ../../hosts/tuxedo/disks.nix
          ../_nixos/docker.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      # ../../home/work.nix is the work overlay, imported only on tuxedo (named aspect at R12).
      home-manager.users.tguimbert.imports = [
        ../../home
        ../../home/work.nix
      ];

      system.stateVersion = "25.11";
    };
  };
}
