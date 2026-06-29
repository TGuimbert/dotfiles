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
  };

  # R6: entry point cutover. `flake.nix` is inputs-only; all logic lives in
  # `outputs.nix`, which evaluates a single `import-tree ./modules`. Every `.nix`
  # under `modules/` is now auto-imported as a flake-parts module, except paths
  # with a `_`-prefixed component (legacy `modules/_nixos/`, `modules/_lib/`),
  # which are migrated/removed in R8+/R13.
  outputs = inputs: import ./outputs.nix inputs;
}
