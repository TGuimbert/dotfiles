{ ... }:
{
  # Shared, host-agnostic constants injected as a module arg so any aspect can
  # read them via `{ constants, ... }:`. Set on `base` (imported by every host),
  # so it is in scope for all NixOS aspects of every configuration.
  nixos.modules.base = {
    _module.args.constants = {
      domain = "home.guimbert.fr";
    };
  };
}
