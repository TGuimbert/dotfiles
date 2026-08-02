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

    # preservation takes nixpkgs-lib passed in by the consumer; it declares no
    # nixpkgs input, so there is nothing to `follows`.
    preservation.url = "github:nix-community/preservation";

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

    # Virtualisation
    #
    # Declarative libvirt objects (srv-01's Home Assistant guest). The branch,
    # not the v0.6.0 tag (May 2025, and no newer one): that tag predates the
    # hostdev `startupPolicy` and graphics `port` attributes used here, and its
    # XML generator drops unknown attributes *silently* rather than failing, so
    # pinning it yields a domain quietly missing them. `follows` matters more
    # than lock hygiene here — NixVirt imports its nixpkgs directly to build the
    # libvirt it hands to the module.
    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop & theming
    arkenfox-nix = {
      url = "github:HeitorAugustoLN/arkenfox-nix";
      inputs.nixpkgs.follows = "unstable";
    };

    # niri compositor — declarative, build-validated config via home-manager.
    # Do NOT override its nixpkgs: like noctalia, overriding changes the niri /
    # xwayland-satellite derivation hashes and defeats niri.cachix.org (they'd
    # then compile from Rust source). Its own nixpkgs only builds those packages.
    niri.url = "github:sodiboo/niri-flake";

    # noctalia shell (v5, native Wayland). Pin the `cachix` branch and DO NOT
    # override its nixpkgs: overriding changes the derivation hash and defeats
    # its cachix cache (noctalia.cachix.org). Its own nixpkgs only builds the
    # noctalia package.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    # noctalia-greeter (greetd greeter matching the shell). Separate project from
    # `noctalia` above, with no cachix of its own — it compiles from source either
    # way, so following our nixpkgs costs nothing and keeps one nixpkgs in the lock.
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
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
