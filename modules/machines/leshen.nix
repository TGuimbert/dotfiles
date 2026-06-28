{ config, inputs, ... }:
{
  nixos.configurations.leshen = {
    # Provide `inputs` to legacy NixOS modules (parity with the old mkSystem specialArgs).
    # Removed once these features become closure-based aspects (R3/R4/R8+).
    args.specialArgs = { inherit inputs; };

    module = {
      imports =
        (with config.nixos.modules; [
          base
          desktop
        ])
        ++ [
          # Global modules formerly injected by mkSystem (move to merge points in R4/R8).
          # R3: core features now arrive via the `desktop` aspect imported above.
          inputs.self.nixosModules.terminal
          inputs.self.nixosModules.helix
          inputs.self.nixosModules.nushell
          inputs.self.nixosModules.zellij
          inputs.self.nixosModules.starship
          inputs.self.nixosModules.cli-tools
          inputs.disko.nixosModules.disko
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.impermanence.nixosModules.impermanence
          inputs.sops-nix.nixosModules.sops
          inputs.stylix.nixosModules.stylix

          # leshen-specific legacy modules (move to machines/ + named aspects later).
          ../../hosts/leshen/hardware.nix
          ../../hosts/leshen/disks.nix
          ../nixos/impermanence.nix
          ../nixos/gnome.nix
          ../nixos/games.nix
          ../nixos/podman.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      # Legacy home wiring (moves into homeManager.modules.{base,gui} in R4/R8). The `base`
      # merge point already imports the home-manager NixOS module, sets useGlobalPkgs /
      # useUserPackages, and seeds users.tguimbert.imports with homeManager.modules.base; the
      # blocks below merge arkenfox + ./home into that.
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
