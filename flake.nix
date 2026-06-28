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

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        imports = [
          (inputs.import-tree ./modules/flake)
          # R2: leshen migrated to nixos.configurations (modules/machines/leshen.nix).
          (inputs.import-tree ./modules/machines)
          # Dendritic core scaffolding (R1). Imported explicitly rather than via
          # import-tree so the legacy modules/nixos stays out of scope until later
          # steps; import-tree widens to all of ./modules at R6.
          ./modules/eval-modules.nix
          ./modules/nixos.nix
          ./modules/home-manager.nix
          ./modules/nixpkgs.nix
          ./modules/users.nix
          # R5: `server` merge point for headless server hosts (srv-01).
          ./modules/server.nix
          # R3: core features, flattened to modules/*.nix and merged into the
          # `desktop` aspect. Listed explicitly (not import-tree'd) for the same
          # reason as the scaffolding above.
          ./modules/boot.nix
          ./modules/locale.nix
          ./modules/networking.nix
          ./modules/audio.nix
          ./modules/nix-settings.nix
          ./modules/services.nix
          ./modules/user.nix
          # R4: shell tools, de-wrapped and flattened to modules/*.nix. System
          # packages merge into the `desktop` aspect; home config into
          # `homeManager.modules.gui` (wired into `desktop` by users.nix).
          ./modules/cli-tools.nix
          ./modules/helix.nix
          ./modules/nushell.nix
          ./modules/starship.nix
          ./modules/terminal.nix
          ./modules/zellij.nix
        ];
        systems = [ "x86_64-linux" ];

        # All hosts are built by the dendritic central generator
        # (config.flake.nixosConfigurations in modules/nixos.nix) from their
        # modules/machines/<host>.nix files. The legacy mkSystem/mkServer builders
        # were removed in R5.
      }
    );
}
