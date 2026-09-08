{
  config,
  inputs,
  lib,
  ...
}:
let
  modules = config.flake.homeModules;
  systems = [
    "x86_64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
  ];
in
{
  # Define these directly rather than expanding perSystem: the existing dev
  # shells and system-wide overlay still contain Linux-specific dependencies.
  flake.checks = lib.genAttrs systems (
    system:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
      evaluate =
        selectedPkgs: imports:
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = selectedPkgs;
          modules = imports ++ [
            {
              home = {
                username = "module-check";
                homeDirectory = if pkgs.stdenv.isDarwin then "/Users/module-check" else "/home/module-check";
                stateVersion = "26.05";
              };
            }
          ];
        };
      overrides =
        (evaluate pkgs [
          modules.terminalSuite
          modules.helixLanguages
          modules.git
          modules.cliTools
          {
            xdg.enable = true;
            xdg.configHome = "/tmp/module check/config";
            programs = {
              nushell = {
                configDir = "/tmp/module check/custom nu";
                extraConfig = "def personal-command [] { 'from consumer' }";
                extraEnv = "$env.PERSONAL_SETTING = 'from consumer'";
              };
              helix.settings.theme = "base16_default_dark";
              zellij.settings.default_shell = "bash";
              zellij.settings.scrollback_editor = "vi";
              starship.settings.palette = "custom";
              starship.settings.palettes.custom = {
                orange = "173";
                base01 = "237";
              };
              bat.config.theme = "base16";
              gh.settings.editor = "vi";
              git.settings.user = {
                name = "Module Check";
                email = "check@example.com";
              };
            };
          }
        ]).config;
    in
    lib.mapAttrs' (
      name: module: lib.nameValuePair "home:${name}" (evaluate pkgs [ module ]).activationPackage
    ) modules
    // {
      "home:terminalOverlay" =
        (evaluate (import inputs.nixpkgs {
          inherit system;
          overlays = [ config.flake.overlays.terminal ];
        }) [ modules.terminalSuite ]).activationPackage;
      "home:overrides" =
        assert overrides.programs.helix.settings.theme == "base16_default_dark";
        assert overrides.programs.zellij.settings.default_shell == "bash";
        assert overrides.programs.gh.settings.editor == "vi";
        assert overrides.programs.git.settings.user.name == "Module Check";
        assert
          if pkgs.stdenv.isDarwin then
            !(lib.hasInfix "private.nu" overrides.programs.nushell.extraConfig)
            && !(lib.hasInfix "private.nu" overrides.programs.nushell.extraEnv)
          else
            lib.hasInfix "/tmp/module check/custom nu/private.nu" overrides.programs.nushell.extraConfig;
        assert lib.hasInfix "/tmp/module check/config" overrides.programs.nushell.extraConfig;
        assert overrides.programs.git.ignores == lib.unique overrides.programs.git.ignores;
        assert overrides.programs.helix.ignores == lib.unique overrides.programs.helix.ignores;
        assert overrides.programs.eza.extraOptions == lib.unique overrides.programs.eza.extraOptions;
        overrides.home.activationPackage;
    }
  );
}
