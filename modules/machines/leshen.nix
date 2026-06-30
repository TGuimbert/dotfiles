{ config, inputs, ... }:
{
  nixos.configurations.leshen = {
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

          ../_hosts/leshen/hardware.nix
          ../_hosts/leshen/disks.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      system.stateVersion = "22.11";
    };
  };
}
