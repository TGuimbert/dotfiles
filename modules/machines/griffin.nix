{ config, inputs, ... }:
{
  nixos.configurations.griffin = {
    module = {
      imports =
        (with config.nixos.modules; [
          base
          desktop
        ])
        ++ [
          inputs.disko.nixosModules.disko
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.impermanence.nixosModules.impermanence
          inputs.sops-nix.nixosModules.sops

          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t490
          ../../hosts/griffin/hardware.nix
          ../../hosts/griffin/disks.nix
          ../_nixos/impermanence.nix
          ../_nixos/games.nix
          ../_nixos/podman.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      home-manager.users.tguimbert.imports = [ ../../home ];

      system.stateVersion = "22.11";
    };
  };
}
