{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.bottom = inputs.nix-wrapper-modules.wrappers.bottom.wrap { inherit pkgs; };
    };
}
