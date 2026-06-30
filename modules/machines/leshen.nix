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

          # leshen-specific legacy modules (move to machines/ + named aspects later).
          ../../hosts/leshen/hardware.nix
          ../../hosts/leshen/disks.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      system.stateVersion = "22.11";
    };
  };
}
