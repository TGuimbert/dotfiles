{ config, inputs, ... }:
{
  nixos.configurations.srv-01 = {
    # `inputs` for legacy NixOS modules (parity with old mkServer specialArgs); dropped at R12.
    args.specialArgs = { inherit inputs; };

    module = {
      imports =
        (with config.nixos.modules; [
          base
          server
        ])
        ++ [
          inputs.disko.nixosModules.disko
          inputs.impermanence.nixosModules.impermanence
          inputs.sops-nix.nixosModules.sops

          ../../hosts/srv-01/hardware.nix
          ../../hosts/srv-01/disks.nix
          ../../hosts/srv-01/default.nix
          ../../hosts/srv-01/printing.nix
          ../../hosts/srv-01/traefik.nix
          ../../hosts/srv-01/lldap.nix
          ../../hosts/srv-01/authelia.nix
          ../../hosts/srv-01/homepage.nix
          ../../hosts/srv-01/restic.nix
          ../../hosts/srv-01/calibre.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      system.stateVersion = "25.11";
    };
  };
}
