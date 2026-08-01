{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.nixos = pkgs.mkShellNoCC {
        buildInputs = with pkgs; [
          cachix
          deadnix
          just
          statix
          nil
        ];
      };
    };
}
