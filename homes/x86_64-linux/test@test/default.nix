{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
{
  home.packages = with pkgs; [
    zsh
  ];

  home.username = "test";
  home.homeDirectory = "/home/test";

  home.stateVersion = "22.11";
}
