{ ... }:
{
  config = {
    # Allow unfree packages
    # nixpkgs.config.allowUnfree = true;
    nix.settings = {
      # Enable flakes
      experimental-features = [ "nix-command" "flakes" ];
      # Add cachix binary cache
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://tguimbert.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "tguimbert.cachix.org-1:PDa22nLjEwxsABhCz09ONTfYAP3DJOAJRszoy007ojs="
      ];
      auto-optimise-store = true;
    };
    nix.gc = {
      automatic = true;
      dates = "weekly";
    };
  };
}

