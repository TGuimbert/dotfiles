{ pkgs, mkShell, inputs, system, channels, ... }:
let
  pythonShell = import ../python { inherit pkgs inputs system channels; };
  nodejsShell = import ../nodejs { inherit pkgs inputs system channels; };
in
mkShell {
  inputsFrom = [
    pythonShell
    nodejsShell
  ];
}

