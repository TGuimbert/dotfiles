{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kind
    kubectx
  ];

  tguimbert.apps.kubectl.enable = true;

  programs = {
    k9s = {
      enable = true;
    };
  };
}
