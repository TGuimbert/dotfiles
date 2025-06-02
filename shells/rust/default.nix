{ pkgs, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    rustc
    cargo
    gcc
    rustfmt
    clippy
    rust-analyzer
    lldb
    pkg-config
    openssl
    rustfinity
  ];
  RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";

  shellHook = ''
    export PATH=$PATH:''${CARGO_HOME:-~/.cargo}/bin
  '';
}
