{ pkgs, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    markdown-oxide
    marksman
  ];
}
