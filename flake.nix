{
  description = "System Config";

  inputs = {
   nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [];
      };

      system = "x86_64-linux";

      util = import ./lib {
        inherit system pkgs home-manager lib;
      };

      inherit (util) host;
    in {
      nixosConfigurations = {
        griffin = host.mkHost {
          name = "griffin";
          userName = "tguimbert";
          initrdAvailMods = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "sdhci_pci" ];
          initrdMods = [ ];
          kernelMods = [ "kvm-intel" ];
          extraModPkgs = [ ];

          systemConfig = {
            miscs.fixTpmInterruptBootMessage = true;
            plymouth.enable = true;
          };
        };
      };

      homeConfigurations."tguimbert@griffin" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [ ./modules/home ] ++ [ ./modules/systems/griffin/home ];
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.nil
        ];
      };
    };
}
