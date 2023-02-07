{ pkgs, home-manager, system, lib, ... }:
rec {
  host = import ./host.nix { inherit pkgs home-manager system lib; };
}