{ pkgs, ... }:

let
  username = "tguimbert";
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.11";

  home.packages = with pkgs; [
    spotify
    yubikey-manager
    rage
    age-plugin-yubikey
    bitwarden-cli
    kubectl
    minikube
    discord
  ];

  home.file = {
    minikubeConfig = {
      target = ".minikube/config/config.json";
      text = builtins.toJSON {
        container-runtime = "containerd";
        rootless = true;
      };
    };
  };

  programs = {
    home-manager.enable = true;
    firefox.enable = true;
    k9s.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
