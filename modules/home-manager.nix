{ lib, ... }:
{
  options.homeManager.modules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
  };
  config.homeManager.modules = {
    base = {
      programs.home-manager.enable = true;
    };
    gui = { };
  };
}
