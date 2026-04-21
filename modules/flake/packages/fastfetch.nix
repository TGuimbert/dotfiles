{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.fastfetch = pkgs.fastfetch;
    };
}
