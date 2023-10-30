{
  description = "System Config";

  inputs = {

    # The flake at the root of the repo, already having all the inputs
    root-flake.url = "git+file:./..";
    # Nixpkgs Unstable;
    nixpkgs.follows = "root-flake/nixpkgs";

    # NixPkgs Stable
    stable.follows = "root-flake/stable";

    # Unified configuration for systems, packages, modules, shells, templates,
    # and more with Nix Flakes
    snowfall-lib.follows = "root-flake/snowfall-lib";

    # Collection of NixOS modules covering hardware quirks
    nixos-hardware.follows = "root-flake/nixos-hardware";

    # Modules to help handle persistent state on systems with ephemeral root
    # storage
    impermanence.follows = "root-flake/impermanence";

    # Secure Boot for NixOS
    lanzaboote.follows = "root-flake/lanzaboote";

    # Manage a user environment using Nix
    home-manager.follows = "root-flake/home-manager";

    # Seamless integration of https://pre-commit.com git hooks with Nix.
    pre-commit-hooks.follows = "root-flake/pre-commit-hooks";

    # Company specific configuration
    scortex = {
      url = "git+ssh://git@github.com/scortexio/nix-config.git";
      # url = "git+file:///home/tguimbert/Workspace/nix-config";
      inputs.nixpkgs.follows = "root-flake/nixpkgs";
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
        src = ./..;
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

      systems.hosts.basilisk.modules = with inputs; [
        nixos-hardware.nixosModules.lenovo-thinkpad-t480
      ];
    };
}
