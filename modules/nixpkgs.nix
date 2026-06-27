{ config, ... }:
let
  nixpkgsSettings = {
    config.allowUnfree = true;
    overlays = [ config.flake.overlays.default ];
  };
in
{
  # NOTE: perSystem `_module.args.pkgs` is intentionally NOT set here; it is already
  # defined in modules/flake/overlays.nix (defining a module arg twice errors). The
  # overlays move into this file at R6, alongside removing the legacy definition.
  nixos.modules.base = {
    nixpkgs = nixpkgsSettings;
  };
}
