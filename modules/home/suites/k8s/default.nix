{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kubectl
    kind
  ];

  programs = {
    k9s = {
      enable = true;
    };
  };
}
