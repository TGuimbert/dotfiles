{ ... }:
{
  # On `base`, not `desktop`: srv-01 evaluates this very flake itself (see
  # `modules/auto-upgrade.nix`), and `modules/nixos.nix` uses `|>` at eval time,
  # so every host needs `pipe-operators` and a cache to pull the result from.
  nixos.modules.base = {
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
      substituters = [
        "https://cache.nixos.org/"
        "https://tguimbert.cachix.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "tguimbert.cachix.org-1:PDa22nLjEwxsABhCz09ONTfYAP3DJOAJRszoy007ojs="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      auto-optimise-store = true;
    };

    # Not `nix.gc.automatic`: nixpkgs warns when both are enabled. `clean` works
    # without `flake`, so a host with no checkout still gets its generations trimmed.
    programs.nh = {
      enable = true;
      clean = {
        enable = true;
        dates = "weekly";
        extraArgs = "--keep 5 --keep-since 3d";
      };
    };
  };

  nixos.modules.desktop = {
    # Appended to the `base` lists — the server would only be querying these for
    # packages it never asks for.
    nix.settings = {
      substituters = [
        "https://niri.cachix.org"
        "https://noctalia.cachix.org"
      ];
      trusted-public-keys = [
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };

    programs = {
      # Only the desktops hold a working copy of this repo.
      nh.flake = "/home/tguimbert/.dotfiles";
      nix-ld.enable = true;
    };

    # Persist Nix's trusted-settings.json so answering the flake `nixConfig`
    # prompt (e.g. our `pipe-operators`) once survives the rollback, instead of
    # being re-asked on every `nix develop`/direnv reload.
    preservation.preserveAt."/persistent".users.tguimbert.directories = [
      ".local/share/nix"
    ];
  };
}
