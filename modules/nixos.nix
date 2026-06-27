{
  config,
  lib,
  inputs,
  evalModulesModule,
  ...
}:
let
  cfg = config.nixos;
in
{
  options.nixos = {
    modules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = { };
    };
    configurations = lib.mkOption {
      type = lib.types.lazyAttrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            imports = [
              evalModulesModule
              {
                fn = inputs.nixpkgs.lib.nixosSystem;
                module = {
                  networking.hostName = lib.mkDefault name;
                };
              }
            ];
          }
        )
      );
      default = { };
    };
  };

  config.flake = {
    nixosConfigurations = cfg.configurations |> lib.mapAttrs (_: c: c.evaluation);
    checks =
      cfg.configurations
      |> lib.mapAttrsToList (
        name: c: {
          ${c.evaluation.config.nixpkgs.hostPlatform.system}."configurations:nixos:${name}" =
            c.evaluation.config.system.build.toplevel;
        }
      )
      |> lib.mkMerge;
  };
}
