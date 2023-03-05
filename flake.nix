{
  description = "System Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    devenv.url = "github:cachix/devenv";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, devenv, ... } @ inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ ];
      };

      inherit (nixpkgs) lib;
    in
    {
      nixosConfigurations = {
        griffin = lib.nixosSystem {
          inherit system;

          modules = [ ./modules/nixos ] ++ [ ./modules/systems/griffin/nixos ];
        };
      };

      homeConfigurations."tguimbert@griffin" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [ ./modules/home ] ++ [ ./modules/systems/griffin/home ];
      };

      devShells.${system}.default = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          {
            languages.nix.enable = true;
            pre-commit.hooks = {
              deadnix.enable = true;
              nixpkgs-fmt.enable = true;
              statix.enable = true;
            };
          }
        ];
      };
    };
}
