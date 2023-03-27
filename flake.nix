{
  description = "System Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    devenv.url = "github:cachix/devenv";
    impermanence.url = "github:nix-community/impermanence";
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    scortex.url = "git+ssh://git@github.com/scortexio/nix-config.git";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... } @ inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ ];
      };

      inherit (nixpkgs) lib;

      user = "tguimbert";

      gaming.modules = [
        {
          tg.gaming.enable = true;
          home-manager.users.tguimbert.imports = [
            {
              tg.gaming.enable = true;
            }
          ];
        }
      ];
    in
    {
      nixosConfigurations = {
        griffin = lib.nixosSystem {
          inherit system;

          modules = [
            home-manager.nixosModules.home-manager
            inputs.impermanence.nixosModules.impermanence
            inputs.lanzaboote.nixosModules.lanzaboote
            ./modules/nixos
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.tguimbert.imports = [
                inputs.impermanence.nixosModules.home-manager.impermanence
                ./modules/home
              ];
            }
          ] ++
          [
            ./modules/systems/griffin/nixos
            {
              home-manager.users.tguimbert = import ./modules/systems/griffin/home;
            }
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t490
          ];
        };

        leshen = lib.nixosSystem {
          inherit system;

          modules = [
            home-manager.nixosModules.home-manager
            inputs.impermanence.nixosModules.impermanence
            inputs.lanzaboote.nixosModules.lanzaboote
            ./modules/nixos

            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.tguimbert.imports = [
                inputs.impermanence.nixosModules.home-manager.impermanence
                ./modules/home
              ];
            }
          ] ++
          [
            ./modules/systems/leshen/nixos
            {
              home-manager.users.tguimbert = import ./modules/systems/leshen/home;
            }
          ] ++ gaming.modules;
        };

        basilisk = lib.nixosSystem {
          inherit system;

          modules = [
            home-manager.nixosModules.home-manager
            inputs.impermanence.nixosModules.impermanence
            inputs.lanzaboote.nixosModules.lanzaboote
            ./modules/nixos
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.tguimbert.imports = [
                inputs.impermanence.nixosModules.home-manager.impermanence
                ./modules/home
              ];
            }
          ] ++
          [
            ./modules/systems/basilisk/nixos
            {
              home-manager.users.tguimbert.imports = [
                ./modules/systems/basilisk/home
                inputs.scortex.nixosModules.home-manager.scortex
              ];
              home-manager.extraSpecialArgs = {
                inherit user;
              };
            }
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480
          ];
        };
      };

      devShells.${system}.default = inputs.devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          {
            languages.nix.enable = true;
            pre-commit.hooks = {
              deadnix.enable = true;
              nixpkgs-fmt.enable = true;
              statix.enable = true;
              actionlint.enable = true;
            };
          }
        ];
      };
    };
}
