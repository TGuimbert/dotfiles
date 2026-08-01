{ config, inputs, ... }:
{
  nixos.configurations.griffin = {
    module = {
      imports =
        (with config.nixos.modules; [
          base
          desktop
          secureBoot
          podman
          games
          laptop
        ])
        ++ [
          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t490
          ../_hosts/griffin/hardware.nix
          ../_hosts/griffin/disks.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      system.stateVersion = "22.11";
    };
  };
}
