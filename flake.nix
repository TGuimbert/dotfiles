{
  description = "System Config";

  # `modules/nixos.nix` uses the `|>` pipe operator at flake-eval time. This nixConfig
  # copy is untrusted, so the first build/check (before the nix-settings change is
  # active) must pass `--accept-flake-config` or `--extra-experimental-features
  # pipe-operators`.
  nixConfig.extra-experimental-features = [ "pipe-operators" ];

  inputs = {
    # Core nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Flake infrastructure (dendritic pattern)
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    # NixOS core modules
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Security & secrets
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Note: tuxedo-nixos requires its pinned nixpkgs (22.11) for nodejs-14_x and electron-13
    # Do not add nixpkgs.follows here as it would break the package
    tuxedo-nixos.url = "github:sund3RRR/tuxedo-nixos";

    # Desktop & theming
    stylix = {
      url = "github:danth/stylix/release-26.05";
      inputs.nixpkgs.follows = "unstable";
    };

    arkenfox-nix = {
      url = "github:HeitorAugustoLN/arkenfox-nix";
      inputs.nixpkgs.follows = "unstable";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Package wrapping
    nix-wrapper-modules = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      import-tree,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      {
        imports = [
          (inputs.import-tree ./modules/flake)
          (inputs.import-tree ./modules/features/shell)
          # Dendritic core scaffolding (R1). Imported explicitly rather than via
          # import-tree so the legacy modules/{features/core,nixos} stay out of scope
          # until later steps; import-tree widens to all of ./modules at R6.
          ./modules/eval-modules.nix
          ./modules/nixos.nix
          ./modules/home-manager.nix
          ./modules/nixpkgs.nix
          ./modules/users.nix
        ];
        systems = [ "x86_64-linux" ];

        flake =
          let
            system = "x86_64-linux";

            pkgsFor =
              s:
              import nixpkgs {
                system = s;
                config.allowUnfree = true;
                overlays = [ config.flake.overlays.default ];
              };

            mkSystem =
              hostname: modules:
              nixpkgs.lib.nixosSystem {
                specialArgs = { inherit inputs; };
                pkgs = pkgsFor system;
                modules = [
                  # Global modules
                  { nixpkgs.hostPlatform = system; }
                  (inputs.import-tree ./modules/features/core)
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
                            inputs.arkenfox-nix.modules.homeManager.arkenfox
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

            mkServer =
              hostname: modules:
              nixpkgs.lib.nixosSystem {
                specialArgs = { inherit inputs; };
                pkgs = pkgsFor system;
                modules = [
                  # Global modules
                  { nixpkgs.hostPlatform = system; }
                  inputs.disko.nixosModules.disko
                  inputs.impermanence.nixosModules.impermanence
                  inputs.sops-nix.nixosModules.sops

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
              tuxedo = mkSystem "tuxedo" [
                inputs.nixos-hardware.nixosModules.tuxedo-infinitybook-pro14-gen9-intel
                inputs.tuxedo-nixos.nixosModules.default
                ./hosts/tuxedo/hardware.nix
                ./hosts/tuxedo/disks.nix
                ./modules/nixos/impermanence.nix
                ./modules/nixos/gnome.nix
                ./modules/nixos/docker.nix

                {
                  home-manager.users.tguimbert = {
                    imports = [ ./home/work.nix ];
                  };
                  system.stateVersion = "25.11";
                }
              ];
              srv-01 = mkServer "srv-01" [
                ./hosts/srv-01/hardware.nix
                ./hosts/srv-01/disks.nix
                ./hosts/srv-01/default.nix
                ./hosts/srv-01/printing.nix
                ./hosts/srv-01/traefik.nix
                ./hosts/srv-01/lldap.nix
                ./hosts/srv-01/authelia.nix
                ./hosts/srv-01/homepage.nix
                ./hosts/srv-01/restic.nix
                ./hosts/srv-01/calibre.nix

                {
                  system.stateVersion = "25.11";
                }
              ];
            };

          };
      }
    );
}
