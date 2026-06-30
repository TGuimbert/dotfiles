{ config, inputs, ... }:
{
  nixos.configurations.leshen = {
    module = {
      imports =
        (with config.nixos.modules; [
          base
          desktop
          podman
        ])
        ++ [
          inputs.disko.nixosModules.disko

          # leshen-specific legacy modules (move to machines/ + named aspects later).
          ../../hosts/leshen/hardware.nix
          ../../hosts/leshen/disks.nix
          ../_nixos/games.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      # ../../home now holds only Steam/games persistence (migrated to steam.nix at R13).
      home-manager.users.tguimbert.imports = [ ../../home ];

      system.stateVersion = "22.11";
    };
  };
}
