{ pkgs, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    protobuf
    buf
  ];
}
