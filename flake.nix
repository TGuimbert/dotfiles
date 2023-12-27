{
  description = "System Config";

  # Flake inputs
  inputs = {
    # Nixpkgs Stable
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

    # Nixpkgs Unstable
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Unified configuration for systems, packages, modules, shells, templates,
    # and more with Nix Flakes
    snowfall-lib = {
      url = "github:snowfallorg/lib/v2.1.1";
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
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Seamless integration of https://pre-commit.com git hooks with Nix.
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
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

      channels-config = {
        allowUnfree = true;
      };

      # Add modules to all systems.
      systems.modules.nixos = with inputs; [
        home-manager.nixosModules.home-manager
        lanzaboote.nixosModules.lanzaboote
        impermanence.nixosModules.impermanence
      ];

      systems.hosts.griffin.modules = with inputs; [
        nixos-hardware.nixosModules.lenovo-thinkpad-t490
      ];
    };
}
