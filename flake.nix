{
  description = "System Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence/master";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix/release-25.05";
      inputs.nixpkgs.follows = "unstable";
    };

    arkenfox-nixos = {
      url = "github:dwarfmaster/arkenfox-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      unstable,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      unstablePkgs = import unstable {
        inherit system;
        config.allowUnfree = true;
      };

      overlays = [
        (import ./overlays { unstable = unstablePkgs; })
      ];

      pkgsFor =
        system:
        import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };

      pkgs = pkgsFor system;

      mkSystem =
        hostname: modules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          pkgs = pkgsFor system;
          modules = [
            # Global modules
            ./modules/nixos/core.nix
            inputs.disko.nixosModules.disko
            inputs.lanzaboote.nixosModules.lanzaboote
            inputs.impermanence.nixosModules.impermanence
            inputs.sops-nix.nixosModules.sops
            inputs.stylix.nixosModules.stylix

            # Home Manager
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.tguimbert =
                  { ... }:
                  {
                    imports = [
                      inputs.arkenfox-nixos.hmModules.arkenfox
                      inputs.impermanence.homeManagerModules.impermanence
                      ./home
                    ];
                  };
                extraSpecialArgs = { inherit inputs; };
              };
            }
            { networking.hostName = hostname; }
          ]
          ++ modules;
        };
    in
    {
      nixosConfigurations = {
        leshen = mkSystem "leshen" [
          ./hosts/leshen/hardware.nix
          ./hosts/leshen/disks.nix
          ./modules/nixos/impermanence.nix
          ./modules/nixos/gnome.nix
          ./modules/nixos/games.nix
          ./modules/nixos/podman.nix

          {
            system.stateVersion = "22.11";
          }
        ];
        griffin = mkSystem "griffin" [
          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t490
          ./hosts/griffin/hardware.nix
          ./hosts/griffin/disks.nix
          ./modules/nixos/impermanence.nix
          ./modules/nixos/gnome.nix
          ./modules/nixos/games.nix
          ./modules/nixos/podman.nix

          {
            system.stateVersion = "22.11";
          }
        ];
        wyvern = mkSystem "wyvern" [
          inputs.nixos-hardware.nixosModules.dell-xps-13-9380
          ./hosts/wyvern/hardware.nix
          ./hosts/wyvern/disks.nix
          ./modules/nixos/impermanence.nix
          ./modules/nixos/gnome.nix
          ./modules/nixos/docker.nix

          {
            home-manager.users.tguimbert = {
              imports = [ ./home/work.nix ];
            };
            system.stateVersion = "23.11";
          }
        ];
      };

      devShells.${system} = {
        nixos = import ./shells/nixos { inherit pkgs; };
        python = import ./shells/python { pkgs = unstablePkgs; };
        rust = import ./shells/rust { inherit pkgs; };
        go = import ./shells/go { inherit pkgs; };
        ops = import ./shells/ops { inherit pkgs; };
        markdown = import ./shells/markdown { inherit pkgs; };
        nodejs = import ./shells/nodejs { inherit pkgs; };
        protobuf = import ./shells/protobuf { inherit pkgs; };

        python-nodejs = pkgs.mkShell {
          inputsFrom = [
            (import ./shells/python { pkgs = unstablePkgs; })
            (import ./shells/nodejs { inherit pkgs; })
          ];
        };
        python-protobuf = pkgs.mkShell {
          inputsFrom = [
            (import ./shells/python { pkgs = unstablePkgs; })
            (import ./shells/protobuf { inherit pkgs; })
          ];
        };
      };

      formatter.${system} = (pkgsFor system).nixfmt-rfc-style;
    };
}
