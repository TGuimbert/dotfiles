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
        "https://tguimbert.cachix.org"
        "https://nix-community.cachix.org"
        "https://devenv.cachix.org"
        "https://nixpkgs-python.cachix.org"
      ];
      trusted-public-keys = [
        "tguimbert.cachix.org-1:PDa22nLjEwxsABhCz09ONTfYAP3DJOAJRszoy007ojs="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
      ];
      auto-optimise-store = true;
    };
    nix.gc = {
      automatic = true;
      dates = "weekly";
    };
  };
}

