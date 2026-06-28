{ config, inputs, ... }:
{
  nixos.configurations.griffin = {
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

          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t490
          ../../hosts/griffin/hardware.nix
          ../../hosts/griffin/disks.nix
          ../nixos/impermanence.nix
          ../nixos/gnome.nix
          ../nixos/games.nix
          ../nixos/podman.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      home-manager = {
        extraSpecialArgs = { inherit inputs; };
        users.tguimbert.imports = [
          inputs.arkenfox-nix.modules.homeManager.arkenfox
          ../../home
        ];
      };

      system.stateVersion = "22.11";
    };
  };
}
