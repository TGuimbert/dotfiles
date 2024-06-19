{ pkgs, mkShell, inputs, system, channels, ... }:
let
  pythonShell = import ../python { inherit pkgs inputs system channels; };
  protobufShell = import ../protobuf { inherit pkgs inputs system channels; };
in
mkShell {
  inputsFrom = [
    pythonShell
    protobufShell
  ];
}

