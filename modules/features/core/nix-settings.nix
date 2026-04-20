{
  lib,
  config,
  ...
}:
{
  options.features.nix-settings.enable = lib.mkEnableOption "nix settings" // {
    default = true;
  };

  config = lib.mkIf config.features.nix-settings.enable {
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
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
  };
}
