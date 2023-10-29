{ pkgs, ... }:
{
  home.packages = with pkgs; [
    yubikey-manager
    rage
    age-plugin-yubikey
    bitwarden-cli
  ];

  programs = {
    home-manager.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
