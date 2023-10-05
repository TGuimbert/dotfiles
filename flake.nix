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
    };

    # Modules to help handle persistent state on systems with ephemeral root
    # storage
    impermanence = {
      url = "github:nix-community/impermanence/master";
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
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    # This is an example and in your actual flake you can use `snowfall-lib.mkFlake`
    # directly unless you explicitly need a feature of `lib`.
    let
      lib = inputs.snowfall-lib.mkLib {
        # You must pass in both your flake's inputs and the root directory of
        # your flake.
        inherit inputs;
        src = ./.;
      };
    in
    lib.mkFlake {
      # Add modules to all systems.
      systems.modules.nixos = with inputs; [
        home-manager.nixosModules.home-manager
        lanzaboote.nixosModules.lanzaboote
        impermanence.nixosModules.impermanence
      ];
    };
  # let
  #   system = "x86_64-linux";
  #   pkgs = import nixpkgs {
  #     inherit system;
  #     config.allowUnfree = true;
  #     overlays = [ ];
  #   };

  #   inherit (nixpkgs) lib;

  #   gaming.modules = [
  #     {
  #       tg.gaming.enable = true;
  #       home-manager.users.tguimbert.imports = [
  #         {
  #           tg.gaming.enable = true;
  #         }
  #       ];
  #     }
  #   ];
  # in
  # {


  #   nixosConfigurations = {
  #     leshen = lib.nixosSystem {
  #       inherit system;

  #       modules = [
  #         home-manager.nixosModules.home-manager
  #         inputs.impermanence.nixosModules.impermanence
  #         inputs.lanzaboote.nixosModules.lanzaboote
  #         ./modules/nixos

  #         {
  #           home-manager.useGlobalPkgs = true;
  #           home-manager.useUserPackages = true;
  #           home-manager.users.tguimbert.imports = [
  #             inputs.impermanence.nixosModules.home-manager.impermanence
  #             ./modules/home
  #           ];
  #         }
  #       ] ++
  #       [
  #         ./modules/systems/leshen/nixos
  #         {
  #           home-manager.users.tguimbert = import ./modules/systems/leshen/home;
  #         }
  #       ] ++ gaming.modules;
  #     };
  #   };

  #   devShells.${system}.default = inputs.devenv.lib.mkShell {
  #     inherit inputs pkgs;
  #     modules = [
  #       {
  #         languages.nix.enable = true;
  #         pre-commit.hooks = {
  #           deadnix.enable = true;
  #           nixpkgs-fmt.enable = true;
  #           statix.enable = true;
  #           actionlint.enable = true;
  #         };
  #       }
  #     ];
  #   };
  # };
}
