{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.foot = inputs.nix-wrapper-modules.wrappers.foot.wrap {
        inherit pkgs;
        settings.main.shell = "nu -c 'zellij -l welcome'";
        settings.main.initial-window-mode = "maximized";
      };
    };
}
