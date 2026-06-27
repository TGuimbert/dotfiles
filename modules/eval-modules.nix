{ lib, ... }:
{
  _module.args.evalModulesModule =
    { config, ... }:
    {
      options = {
        fn = lib.mkOption { type = lib.types.functionTo lib.types.attrs; };
        module = lib.mkOption { type = lib.types.deferredModule; };
        args = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.anything;
          default = { };
        };
        evaluation = lib.mkOption {
          readOnly = true;
          type = lib.types.attrs;
          default = config.fn (config.args // { modules = [ config.module ]; });
        };
      };
    };
}
