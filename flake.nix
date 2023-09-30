{
  description = "System Config";

  # Flake inputs
  inputs = {
    # Nixpkgs Unstable
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Unified configuration for systems, packages, modules, shells, templates,
    # and more with Nix Flakes
    snowfall-lib = {
      url = "github:snowfallorg/lib/v2.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Collection of NixOS modules covering hardware quirks
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Modules to help handle persistent state on systems with ephemeral root
    # storage
    impermanence = {
      url = "github:nix-community/impermanence/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure Boot for NixOS
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Manage a user environment using Nix
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Fast, Declarative, Reproducible, and Composable Developer Environments
    devenv = {
      url = "github:cachix/devenv/main";
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
