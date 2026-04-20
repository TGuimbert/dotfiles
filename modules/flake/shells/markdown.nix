{ ... }:
{
  perSystem = { pkgs, ... }: {
    devShells.markdown = pkgs.mkShell {
      packages = with pkgs; [
        markdown-oxide
        marksman
      ];
    };
  };
}
