{ config, lib, ... }:
{
  options.homeManager.modules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    # Deferred modules are anonymous by default. Give each aspect a stable key
    # so importing a bundle alongside an individual app does not duplicate lists.
    apply = lib.mapAttrs (name: module: module // { key = "${toString ./.}/homeModules/${name}"; });
  };
  config.flake.homeModules = lib.genAttrs [
    "helix"
    "helixLanguages"
    "zellij"
    "nushell"
    "starship"
    "bat"
    "eza"
    "zoxide"
    "cliTools"
    "git"
    "difftastic"
    "direnv"
    "gh"
    "gpg"
    "bash"
    "terminalSuite"
  ] (name: config.homeManager.modules.${name});

  config.homeManager.modules = {
    base = {
      programs.home-manager.enable = true;
    };
    gui = { };
    terminalSuite = {
      imports = with config.homeManager.modules; [
        helix
        zellij
        nushell
        starship
        cliTools
        git
        difftastic
        direnv
        gh
        gpg
        bash
      ];
    };
  };
}
