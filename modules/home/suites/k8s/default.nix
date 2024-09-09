{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kubectl
    kind
    kubectx
  ];

  programs = {
    k9s = {
      enable = true;
    };
  };
}
