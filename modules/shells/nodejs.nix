{ ... }:
{
  perSystem = { pkgs, ... }: {
    devShells.nodejs = pkgs.mkShell {
      packages = with pkgs; [
        nodejs_22
        corepack
      ];
    };
  };
}
