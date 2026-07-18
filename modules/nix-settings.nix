{ ... }:
{
  nixos.modules.desktop = {
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
    programs = {
      nh = {
        enable = true;
        flake = "/home/tguimbert/.dotfiles";
        clean = {
          enable = true;
          dates = "weekly";
          extraArgs = "--keep 5 --keep-since 3d";
        };
      };
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
