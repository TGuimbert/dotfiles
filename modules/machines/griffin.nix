{ config, inputs, ... }:
{
  nixos.configurations.griffin = {
    module = {
      imports =
        (with config.nixos.modules; [
          base
          desktop
          podman
          games
        ])
        ++ [
          inputs.disko.nixosModules.disko

          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t490
          ../../hosts/griffin/hardware.nix
          ../../hosts/griffin/disks.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      system.stateVersion = "22.11";
    };
  };
}
