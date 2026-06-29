{ ... }:
{
  perSystem = { pkgs, ... }: {
    devShells.protobuf = pkgs.mkShell {
      packages = with pkgs; [
        protobuf
        buf
      ];
    };
  };
}
