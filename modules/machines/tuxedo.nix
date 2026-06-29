{ config, inputs, ... }:
{
  nixos.configurations.tuxedo = {
    # `inputs` for legacy NixOS modules (parity with old mkSystem specialArgs); dropped at R8+.
    args.specialArgs = { inherit inputs; };

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
          inputs.stylix.nixosModules.stylix

          inputs.nixos-hardware.nixosModules.tuxedo-infinitybook-pro14-gen9-intel
          inputs.tuxedo-nixos.nixosModules.default
          ../../hosts/tuxedo/hardware.nix
          ../../hosts/tuxedo/disks.nix
          ../_nixos/impermanence.nix
          ../_nixos/gnome.nix
          ../_nixos/docker.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      # ../../home/work.nix is the work overlay, imported only on tuxedo (named aspect at R12).
      home-manager = {
        extraSpecialArgs = { inherit inputs; };
        users.tguimbert.imports = [
          inputs.arkenfox-nix.modules.homeManager.arkenfox
          ../../home
          ../../home/work.nix
        ];
      };

      system.stateVersion = "25.11";
    };
  };
}
