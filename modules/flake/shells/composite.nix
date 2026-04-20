{ ... }:
{
  perSystem = { pkgs, config, ... }: {
    devShells = {
      python-nodejs = pkgs.mkShell {
        inputsFrom = [
          config.devShells.python
          config.devShells.nodejs
        ];
      };
      python-protobuf = pkgs.mkShell {
        inputsFrom = [
          config.devShells.python
          config.devShells.protobuf
        ];
      };
    };
  };
}
