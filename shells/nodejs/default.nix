{ pkgs, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    nodejs_20
    corepack
  ];
}
