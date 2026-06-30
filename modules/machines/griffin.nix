{ config, inputs, ... }:
{
  nixos.configurations.griffin = {
    module = {
      imports =
        (with config.nixos.modules; [
          base
          desktop
          podman
        ])
        ++ [
          inputs.disko.nixosModules.disko

          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t490
          ../../hosts/griffin/hardware.nix
          ../../hosts/griffin/disks.nix
          ../_nixos/games.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      # ../../home now holds only Steam/games persistence (migrated to steam.nix at R13).
      home-manager.users.tguimbert.imports = [ ../../home ];

      system.stateVersion = "22.11";
    };
  };
}
