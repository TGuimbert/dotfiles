{ options, pkgs, lib, ... }:
with lib;
with pkgs.lib.options;
{
  options.tguimbert.virtualisation = {
    containerPlatform =
      mkOption {
        type = types.nullOr (types.enum [ "podman" "docker" ]);
        default = null;
        description =
          lib.mdDoc ''
            This option determines which container platform to use. By default
            it does not install any.
          '';
      };
  };

}
