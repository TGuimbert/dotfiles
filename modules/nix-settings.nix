{ ... }:
{
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
      nh.flake = "/home/tguimbert/.dotfiles";
      nix-ld.enable = true;
    };

    preservation.preserveAt."/persistent".users.tguimbert.directories = [
      ".local/share/nix"
    ];
  };
}
