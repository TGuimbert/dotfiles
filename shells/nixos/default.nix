{
  pkgs,
  ...
}:
pkgs.mkShellNoCC {
  buildInputs = with pkgs; [
    cachix
    nixfmt-rfc-style
    deadnix
    statix
    nil
  ];
}
